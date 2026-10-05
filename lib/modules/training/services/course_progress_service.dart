import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../models/course_progress_model.dart';

class CourseProgressService {
  final FirebaseFirestore firestore;

  CourseProgressService({
    FirebaseFirestore? firestore,
  }) : firestore =
      firestore ?? FirebaseFirestore.instance;

  // ============================================================
  // GET COURSE PROGRESS
  // ============================================================

  Future<CourseProgressModel> getCourseProgress({
    required String userId,
    required String courseId,
    required List<String> lessonIds,
  }) async {
    int completedLessons = 0;
    int completedVideos = 0;
    int submittedQuizzes = 0;

    int totalQuizScore = 0;
    int quizCount = 0;

    DateTime? latestCompletionDate;

    // ============================================================
    // LOAD CURRENT LESSON CONFIGURATION
    //
    // This is important because quizEnabled can be changed by
    // Super Admin after trainee progress has already been saved.
    // ============================================================

    final lessonsSnapshot = await firestore
        .collection("training_courses")
        .doc(courseId)
        .collection("lessons")
        .get();

    final Map<String, bool> quizEnabledByLessonId = {};

    for (final doc in lessonsSnapshot.docs) {
      final data = doc.data();

      quizEnabledByLessonId[doc.id] =
          data["quizEnabled"] == true;
    }

    // ============================================================
    // LOAD ALL TRAINEE PROGRESS
    //
    // One Firestore request instead of one request per lesson.
    // ============================================================

    final progressSnapshot = await firestore
        .collection("users")
        .doc(userId)
        .collection("training_progress")
        .doc(courseId)
        .collection("lessons")
        .get();

    final Map<String, Map<String, dynamic>> progressByLessonId = {};

    for (final doc in progressSnapshot.docs) {
      progressByLessonId[doc.id] = doc.data();
    }

    // ============================================================
    // CALCULATE PROGRESS LOCALLY
    // ============================================================

    for (final lessonId in lessonIds) {
      final data = progressByLessonId[lessonId];

      if (data == null) {
        continue;
      }

      final bool videoCompleted =
          data["videoCompleted"] == true;

      final bool quizSubmitted =
          data["quizSubmitted"] == true;

      final bool storedCompleted =
          data["completed"] == true;

      // ==========================================================
      // CURRENT QUIZ CONFIGURATION
      // ==========================================================

      final bool quizEnabled =
          quizEnabledByLessonId[lessonId] == true;

      // ==========================================================
      // VIDEO
      // ==========================================================

      if (videoCompleted) {
        completedVideos++;
      }

      // ==========================================================
      // QUIZ
      //
      // Only count quiz data if the quiz is CURRENTLY enabled.
      //
      // This prevents an old quizSubmitted value from affecting
      // a lesson after Super Admin disables its quiz.
      // ==========================================================

      if (quizEnabled && quizSubmitted) {
        submittedQuizzes++;

        final dynamic scoreValue =
        data["score"];

        if (scoreValue is num) {
          totalQuizScore += scoreValue.toInt();
          quizCount++;
        }
      }

      // ==========================================================
      // LESSON COMPLETION
      // ==========================================================
      //
      // QUIZ DISABLED:
      //     videoCompleted => lesson completed
      //
      // QUIZ ENABLED:
      //     quizSubmitted => lesson completed
      //
      // storedCompleted is also respected for existing completed
      // lessons.
      // ==========================================================

      bool effectiveCompleted;

      if (!quizEnabled) {
        effectiveCompleted =
            storedCompleted || videoCompleted;
      } else {
        effectiveCompleted =
            storedCompleted || quizSubmitted;
      }

      if (effectiveCompleted) {
        completedLessons++;

        final completedAt =
        data["completedAt"];

        if (completedAt is Timestamp) {
          final date = completedAt.toDate();

          if (latestCompletionDate == null ||
              date.isAfter(latestCompletionDate!)) {
            latestCompletionDate = date;
          }
        }
      }
    }

    // ============================================================
    // COURSE PERCENTAGE
    // ============================================================

    double percentage = 0;

    if (lessonIds.isNotEmpty) {
      percentage =
          (completedLessons / lessonIds.length) * 100;
    }

    // ============================================================
    // QUIZ AVERAGE
    // ============================================================

    double averageQuizScore = 0;

    if (quizCount > 0) {
      averageQuizScore =
          totalQuizScore / quizCount;
    }

    // ============================================================
    // COURSE COMPLETION
    // ============================================================

    final bool courseCompleted =
        lessonIds.isNotEmpty &&
            completedLessons == lessonIds.length;

    debugPrint(
      'Course $courseId => '
          'completed: $completedLessons / ${lessonIds.length}, '
          'videos: $completedVideos, '
          'quizzes: $submittedQuizzes, '
          'quiz avg: $averageQuizScore, '
          'progress: $percentage%',
    );

    return CourseProgressModel(
      totalLessons: lessonIds.length,
      completedLessons: completedLessons,
      completedVideos: completedVideos,
      submittedQuizzes: submittedQuizzes,
      progressPercentage: percentage,
      averageQuizScore: averageQuizScore,
      courseCompleted: courseCompleted,
      completedAt:
      courseCompleted
          ? latestCompletionDate
          : null,
    );
  }
}