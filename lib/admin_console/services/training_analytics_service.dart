import 'package:cloud_firestore/cloud_firestore.dart';

import '../../modules/training/models/agent_training_analytics_model.dart';

class TrainingAnalyticsService {
  final FirebaseFirestore firestore;

  TrainingAnalyticsService({
    FirebaseFirestore? firestore,
  }) : firestore =
      firestore ?? FirebaseFirestore.instance;

  // ============================================================
  // ANALYTICS CACHE
  // ============================================================

  static List<AgentTrainingAnalyticsModel>?
  _cachedAnalytics;

  static DateTime? _analyticsCacheTime;

  static const Duration _analyticsCacheDuration =
  Duration(minutes: 5);

  // ============================================================
  // COURSE METADATA CACHE
  //
  // Course metadata changes much less frequently than analytics.
  // Keeping this separately avoids rebuilding course information
  // every time the analytics screen opens.
  // ============================================================

  static List<QueryDocumentSnapshot<Map<String, dynamic>>>?
  _cachedCourses;

  static Map<String, String>?
  _cachedCourseNames;

  static Map<String, List<String>>?
  _cachedCourseLessonIds;

  static DateTime? _courseCacheTime;

  static const Duration _courseCacheDuration =
  Duration(minutes: 10);

  // ============================================================
  // GET ALL TRAINEE ANALYTICS
  // ============================================================

  Future<List<AgentTrainingAnalyticsModel>>
  getAllTraineeAnalytics({
    bool forceRefresh = false,
  }) async {
    // ----------------------------------------------------------
    // RETURN ANALYTICS CACHE
    // ----------------------------------------------------------

    if (!forceRefresh &&
        _cachedAnalytics != null &&
        _analyticsCacheTime != null &&
        DateTime.now()
            .difference(_analyticsCacheTime!) <
            _analyticsCacheDuration) {
      return _cachedAnalytics!;
    }

    // ----------------------------------------------------------
    // LOAD TRAINEES AND COURSE METADATA IN PARALLEL
    // ----------------------------------------------------------

    final traineesFuture = firestore
        .collection('users')
        .where(
      'role',
      isEqualTo: 'trainee',
    )
        .get();

    final courseMetadataFuture =
    _getCourseMetadata(
      forceRefresh: forceRefresh,
    );

    final results = await Future.wait([
      traineesFuture,
      courseMetadataFuture,
    ]);

    final usersSnapshot =
    results[0]
    as QuerySnapshot<Map<String, dynamic>>;

    final courseMetadata =
    results[1] as _CourseMetadata;

    final realCourses =
        courseMetadata.realCourses;

    // ----------------------------------------------------------
    // BUILD TRAINEE ANALYTICS IN PARALLEL
    //
    // Every trainee is processed independently.
    // ----------------------------------------------------------

    if (usersSnapshot.docs.isEmpty ||
        realCourses.isEmpty) {
      final emptyResult =
      <AgentTrainingAnalyticsModel>[];

      _cachedAnalytics = emptyResult;
      _analyticsCacheTime = DateTime.now();

      return emptyResult;
    }

    final analytics = await Future.wait(
      usersSnapshot.docs.map(
            (userDoc) => _buildTraineeAnalytics(
          userDoc: userDoc,
          realCourses: realCourses,
          courseLessonIds:
          courseMetadata.courseLessonIds,
          courseNames:
          courseMetadata.courseNames,
        ),
      ),
    );

    // ----------------------------------------------------------
    // UPDATE CACHE
    // ----------------------------------------------------------

    _cachedAnalytics = analytics;
    _analyticsCacheTime = DateTime.now();

    return analytics;
  }

  // ============================================================
  // COURSE METADATA
  // ============================================================

  Future<_CourseMetadata> _getCourseMetadata({
    bool forceRefresh = false,
  }) async {
    // ----------------------------------------------------------
    // RETURN COURSE CACHE
    // ----------------------------------------------------------

    if (!forceRefresh &&
        _cachedCourses != null &&
        _cachedCourseNames != null &&
        _cachedCourseLessonIds != null &&
        _courseCacheTime != null &&
        DateTime.now()
            .difference(_courseCacheTime!) <
            _courseCacheDuration) {
      return _CourseMetadata(
        courses: _cachedCourses!,
        courseNames: _cachedCourseNames!,
        courseLessonIds:
        _cachedCourseLessonIds!,
      );
    }

    // ----------------------------------------------------------
    // LOAD COURSES
    // ----------------------------------------------------------

    final coursesSnapshot = await firestore
        .collection('training_courses')
        .get();

    final courseNames = <String, String>{};

    // ----------------------------------------------------------
    // LOAD LESSONS IN PARALLEL
    // ----------------------------------------------------------

    final lessonResults = await Future.wait(
      coursesSnapshot.docs.map(
            (courseDoc) async {
          final courseId = courseDoc.id;

          final data = courseDoc.data();

          courseNames[courseId] =
              data['title']?.toString() ??
                  courseId;

          final lessonsSnapshot =
          await firestore
              .collection(
            'training_courses',
          )
              .doc(courseId)
              .collection('lessons')
              .get();

          return MapEntry(
            courseId,
            lessonsSnapshot.docs
                .map(
                  (lessonDoc) =>
              lessonDoc.id,
            )
                .toList(),
          );
        },
      ),
    );

    final courseLessonIds =
    Map<String, List<String>>.fromEntries(
      lessonResults,
    );

    // ----------------------------------------------------------
    // ONLY COURSES WITH LESSONS
    // ----------------------------------------------------------

    final realCourses =
    coursesSnapshot.docs.where(
          (courseDoc) {
        final lessons =
            courseLessonIds[courseDoc.id] ??
                const <String>[];

        return lessons.isNotEmpty;
      },
    ).toList();

    // ----------------------------------------------------------
    // UPDATE COURSE CACHE
    // ----------------------------------------------------------

    _cachedCourses = realCourses;

    _cachedCourseNames = courseNames;

    _cachedCourseLessonIds =
        courseLessonIds;

    _courseCacheTime = DateTime.now();

    return _CourseMetadata(
      courses: realCourses,
      courseNames: courseNames,
      courseLessonIds: courseLessonIds,
    );
  }

  // ============================================================
  // BUILD ONE TRAINEE
  // ============================================================

  Future<AgentTrainingAnalyticsModel>
  _buildTraineeAnalytics({
    required QueryDocumentSnapshot<
        Map<String, dynamic>>
    userDoc,
    required List<QueryDocumentSnapshot<
        Map<String, dynamic>>>
    realCourses,
    required Map<String, List<String>>
    courseLessonIds,
    required Map<String, String>
    courseNames,
  }) async {
    final userId = userDoc.id;

    final userData = userDoc.data();

    // ----------------------------------------------------------
    // USER NAME
    // ----------------------------------------------------------

    final displayName =
    userData['displayName']
        ?.toString()
        .trim();

    final email =
    userData['email']?.toString();

    final userName =
    displayName != null &&
        displayName.isNotEmpty
        ? displayName
        : email != null &&
        email.isNotEmpty
        ? email
        : 'Unknown';

    // ==========================================================
    // LOAD ALL COURSE PROGRESS IN PARALLEL
    // ==========================================================

    final progressResults = await Future.wait(
      realCourses.map(
            (courseDoc) async {
          final courseId =
              courseDoc.id;

          final snapshot =
          await firestore
              .collection('users')
              .doc(userId)
              .collection(
            'training_progress',
          )
              .doc(courseId)
              .collection('lessons')
              .get();

          return MapEntry(
            courseId,
            snapshot,
          );
        },
      ),
    );

    final Map<String,
        QuerySnapshot<Map<String, dynamic>>>
    progressByCourse =
    Map.fromEntries(
      progressResults,
    );

    // ==========================================================
    // ONLY CHECK CERTIFICATES FOR COURSES WITH PROGRESS
    //
    // This avoids certificate reads for courses the trainee
    // has never started.
    // ==========================================================

    final coursesWithProgress =
    progressByCourse.entries
        .where(
          (entry) =>
      entry.value.docs.isNotEmpty,
    )
        .map(
          (entry) => entry.key,
    )
        .toSet();

    final certificateResults =
    await Future.wait(
      coursesWithProgress.map(
            (courseId) async {
          final certificateId =
              '${userId}_$courseId';

          final snapshot =
          await firestore
              .collection('certificates')
              .doc(certificateId)
              .get();

          return MapEntry(
            courseId,
            snapshot,
          );
        },
      ),
    );

    final Map<String,
        DocumentSnapshot<Map<String, dynamic>>>
    certificatesByCourse =
    Map.fromEntries(
      certificateResults,
    );

    // ==========================================================
    // COURSE ANALYTICS
    // ==========================================================

    final List<CourseAnalyticsModel>
    userCourses = [];

    double totalProgress = 0;

    int totalQuizScore = 0;

    int totalSubmittedQuizzes = 0;

    int completedCourses = 0;

    // ==========================================================
    // PROCESS COURSES LOCALLY
    // ==========================================================

    for (final courseDoc in realCourses) {
      final courseId =
          courseDoc.id;

      final actualLessonIds =
          courseLessonIds[courseId] ??
              const <String>[];

      final progressSnapshot =
      progressByCourse[courseId];

      // --------------------------------------------------------
      // COURSE NOT STARTED
      //
      // Keep the old behaviour: courses without progress are
      // not included in the trainee's analytics.
      // --------------------------------------------------------

      if (progressSnapshot == null ||
          progressSnapshot.docs.isEmpty) {
        continue;
      }

      final actualLessonIdSet =
      actualLessonIds.toSet();

      int completedLessons = 0;

      int courseTotalQuizScore = 0;

      int courseQuizCount = 0;

      DateTime? latestCompletionDate;

      // --------------------------------------------------------
      // PROCESS LESSON PROGRESS
      // --------------------------------------------------------

      for (final lessonProgressDoc
      in progressSnapshot.docs) {
        final lessonId =
            lessonProgressDoc.id;

        if (!actualLessonIdSet
            .contains(lessonId)) {
          continue;
        }

        final data =
        lessonProgressDoc.data();

        // ------------------------------------------------------
        // LESSON COMPLETION
        // ------------------------------------------------------

        if (data['completed'] == true) {
          completedLessons++;

          final completedAt =
          data['completedAt'];

          if (completedAt is Timestamp) {
            final date =
            completedAt.toDate();

            if (latestCompletionDate ==
                null ||
                date.isAfter(
                  latestCompletionDate!,
                )) {
              latestCompletionDate =
                  date;
            }
          }
        }

        // ------------------------------------------------------
        // QUIZ
        // ------------------------------------------------------

        if (data['quizSubmitted'] == true) {
          final num score =
              (data['score'] as num?) ??
                  0;

          final int scoreValue =
          score.toInt();

          courseTotalQuizScore +=
              scoreValue;

          courseQuizCount++;

          totalQuizScore +=
              scoreValue;

          totalSubmittedQuizzes++;
        }
      }

      // ========================================================
      // TOTAL LESSONS
      // ========================================================

      final int totalLessons =
          actualLessonIds.length;

      // ========================================================
      // COURSE PROGRESS
      // ========================================================

      final double progress =
      totalLessons == 0
          ? 0
          : (completedLessons /
          totalLessons) *
          100;

      // ========================================================
      // COURSE QUIZ AVERAGE
      // ========================================================

      final double quizScore =
      courseQuizCount == 0
          ? 0
          : courseTotalQuizScore /
          courseQuizCount;

      // ========================================================
      // COURSE COMPLETION
      // ========================================================

      final bool completed =
          totalLessons > 0 &&
              completedLessons >=
                  totalLessons;

      if (completed) {
        completedCourses++;
      }

      totalProgress += progress;

      // ========================================================
      // CERTIFICATE
      // ========================================================

      final certificateSnapshot =
      certificatesByCourse[courseId];

      bool certificateIssued = false;

      String? certificateUrl;

      DateTime? certificateIssuedAt;

      if (certificateSnapshot != null &&
          certificateSnapshot.exists) {
        final certificateData =
        certificateSnapshot.data();

        certificateIssued = true;

        certificateUrl =
            certificateData?[
            'certificateUrl']
                ?.toString();

        final issuedAt =
        certificateData?['issuedAt'];

        if (issuedAt is Timestamp) {
          certificateIssuedAt =
              issuedAt.toDate();
        }
      }

      // ========================================================
      // COURSE ANALYTICS MODEL
      // ========================================================

      userCourses.add(
        CourseAnalyticsModel(
          courseId: courseId,
          courseName:
          courseNames[courseId] ??
              courseId,
          totalLessons:
          totalLessons,
          completedLessons:
          completedLessons,
          progress: progress,
          quizScore: quizScore,
          completed: completed,
          certificateIssued:
          certificateIssued,
          certificateUrl:
          certificateUrl,
          certificateIssuedAt:
          certificateIssuedAt,
        ),
      );
    }

    // ==========================================================
    // TOTAL COURSES
    // ==========================================================

    final int totalCourses =
        userCourses.length;

    // ==========================================================
    // OVERALL PROGRESS
    // ==========================================================

    final double overallProgress =
    totalCourses == 0
        ? 0
        : totalProgress /
        totalCourses;

    // ==========================================================
    // OVERALL QUIZ SCORE
    // ==========================================================

    final double averageQuizScore =
    totalSubmittedQuizzes == 0
        ? 0
        : totalQuizScore /
        totalSubmittedQuizzes;

    // ==========================================================
    // TRAINEE ANALYTICS
    // ==========================================================

    return AgentTrainingAnalyticsModel(
      userId: userId,
      userName: userName,
      totalCourses: totalCourses,
      completedCourses:
      completedCourses,
      overallProgress:
      overallProgress,
      averageQuizScore:
      averageQuizScore,
      courses: userCourses,
    );
  }

  // ============================================================
  // CLEAR CACHE
  //
  // Call this after training progress/course/certificate data
  // changes and the analytics screen needs fresh data.
  // ============================================================

  static void clearCache() {
    _cachedAnalytics = null;

    _analyticsCacheTime = null;
  }

  // ============================================================
  // CLEAR EVERYTHING
  //
  // Useful after course structure changes.
  // ============================================================

  static void clearAllCaches() {
    _cachedAnalytics = null;
    _analyticsCacheTime = null;

    _cachedCourses = null;
    _cachedCourseNames = null;
    _cachedCourseLessonIds = null;
    _courseCacheTime = null;
  }
}

// ============================================================
// COURSE METADATA RESULT
// ============================================================

class _CourseMetadata {
  final List<QueryDocumentSnapshot<
      Map<String, dynamic>>> courses;

  final Map<String, String> courseNames;

  final Map<String, List<String>>
  courseLessonIds;

  const _CourseMetadata({
    required this.courses,
    required this.courseNames,
    required this.courseLessonIds,
  });

  List<QueryDocumentSnapshot<
      Map<String, dynamic>>>
  get realCourses => courses;
}