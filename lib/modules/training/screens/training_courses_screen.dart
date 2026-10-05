import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../models/course_model.dart';
import '../repositories/firebase_training_repository.dart';
import '../widgets/course_card.dart';

// ============================================================
// TRAINING COURSES SCREEN
// ============================================================
//
// Dedicated course library for the Training Portal.
//
// Responsibilities:
// - Load available courses
// - Load individual course progress
// - Display course cards
// - Navigate to course details
// - Refresh course data
//
// Dashboard should NOT duplicate this course grid.
//
// ============================================================

class TrainingCoursesScreen extends StatefulWidget {
  const TrainingCoursesScreen({
    super.key,
  });

  @override
  State<TrainingCoursesScreen> createState() =>
      _TrainingCoursesScreenState();
}

class _TrainingCoursesScreenState
    extends State<TrainingCoursesScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final FirebaseTrainingRepository _repository =
  FirebaseTrainingRepository();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // STATE
  // ============================================================

  List<CourseModel>? _courses;

  Map<String, Map<String, dynamic>> _progressMap = {};

  bool _loading = true;

  bool _loadingProgress = false;

  bool _refreshing = false;

  String? _errorMessage;

  int _loadGeneration = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCourses();
  }

  // ============================================================
  // LOAD COURSES
  // ============================================================

  Future<void> _loadCourses() async {
    final generation = ++_loadGeneration;

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadingProgress = false;
        _courses = [];
        _progressMap = {};
      });

      return;
    }

    try {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });

      final courses =
      await _repository.getCourses();

      if (!mounted ||
          generation != _loadGeneration) {
        return;
      }

      setState(() {
        _courses = courses;
        _loading = false;
        _loadingProgress = true;
      });

      final progress =
      await _loadCoursesProgress(
        courses: courses,
        userId: user.uid,
      );

      if (!mounted ||
          generation != _loadGeneration) {
        return;
      }

      setState(() {
        _progressMap = progress;
        _loadingProgress = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'TrainingCoursesScreen error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted ||
          generation != _loadGeneration) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingProgress = false;
        _errorMessage =
        'Failed to load training courses.';
      });
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshCourses() async {
    if (_refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      await _loadCourses();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  // ============================================================
  // LOAD ALL COURSE PROGRESS
  // ============================================================

  Future<Map<String, Map<String, dynamic>>>
  _loadCoursesProgress({
    required List<CourseModel> courses,
    required String userId,
  }) async {
    if (courses.isEmpty) {
      return {};
    }

    final results =
    await Future.wait(
      courses.map(
            (course) async {
          try {
            return MapEntry(
              course.id,
              await _loadSingleCourseProgress(
                course: course,
                userId: userId,
              ),
            );
          } catch (e) {
            debugPrint(
              'Progress error ${course.id}: $e',
            );

            return MapEntry(
              course.id,
              {
                'progress': 0.0,
                'lessons': 0,
                'duration': 0,
              },
            );
          }
        },
      ),
    );

    return Map.fromEntries(
      results,
    );
  }

  // ============================================================
  // LOAD SINGLE COURSE PROGRESS
  // ============================================================

  Future<Map<String, dynamic>>
  _loadSingleCourseProgress({
    required CourseModel course,
    required String userId,
  }) async {
    final lessons =
    await _repository.getLessons(
      course.id,
    );

    final totalDuration =
    lessons.fold<int>(
      0,
          (
          total,
          lesson,
          ) =>
      total + lesson.duration,
    );

    if (lessons.isEmpty) {
      return {
        'progress': 0.0,
        'lessons': 0,
        'duration': totalDuration,
      };
    }

    final snapshot =
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('training_progress')
        .doc(course.id)
        .collection('lessons')
        .get(
      const GetOptions(
        source: Source.server,
      ),
    );

    final Map<String, Map<String, dynamic>>
    progressByLesson = {};

    for (final doc in snapshot.docs) {
      progressByLesson[doc.id] =
          doc.data();
    }

    double totalProgress = 0;

    for (final lesson in lessons) {
      final data =
          progressByLesson[lesson.id] ?? {};

      final completed =
          data['completed'] == true;

      final videoCompleted =
          data['videoCompleted'] == true;

      final quizSubmitted =
          data['quizSubmitted'] == true;

      double lessonProgress = 0;

      if (lesson.quizEnabled) {
        if (videoCompleted) {
          lessonProgress += 0.5;
        }

        if (quizSubmitted) {
          lessonProgress += 0.5;
        }

        if (completed) {
          lessonProgress = 1;
        }
      } else {
        if (completed ||
            videoCompleted) {
          lessonProgress = 1;
        }
      }

      totalProgress +=
          lessonProgress;
    }

    final percentage =
        (totalProgress /
            lessons.length) *
            100;

    return {
      'progress': percentage,
      'lessons': lessons.length,
      'duration': totalDuration,
    };
  }

  // ============================================================
  // NAVIGATE TO COURSE
  // ============================================================

  void _openCourse(
      CourseModel course,
      ) {
    context.go(
      AppRouter.coursePath(
        course.id,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    if (_loading) {
      return const _CoursesLoading();
    }

    if (_errorMessage != null) {
      return _CoursesError(
        message: _errorMessage!,
        onRetry: _loadCourses,
      );
    }

    final courses =
        _courses ?? [];

    if (courses.isEmpty) {
      return const _EmptyCoursesState();
    }

    return Container(
      color:
      theme.colorScheme.surface,

      child:
      SingleChildScrollView(
        physics:
        const BouncingScrollPhysics(),

        padding:
        const EdgeInsets.all(
          32,
        ),

        child:
        Center(
          child:
          ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth: 1600,
            ),

            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                // ==================================================
                // HEADER
                // ==================================================

                _buildHeader(
                  context,
                  courses.length,
                ),

                const SizedBox(
                  height: 28,
                ),

                // ==================================================
                // COURSE CONTENT
                // ==================================================

                _loadingProgress
                    ? Padding(
                  padding:
                  const EdgeInsets.symmetric(
                    vertical: 120,
                  ),
                  child:
                  Center(
                    child:
                    CircularProgressIndicator(
                      color:
                      theme.colorScheme.primary,
                    ),
                  ),
                )
                    : _buildCourseGrid(
                  courses,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
      BuildContext context,
      int courseCount,
      ) {
    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 650;

      final headerContent = [
        Expanded(
          flex: isCompact ? 0 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Courses',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Explore your available training courses and continue learning.',
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$courseCount ${courseCount == 1 ? 'Course' : 'Courses'} Available',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isCompact) const SizedBox(height: 20) else const SizedBox(width: 20),
        Material(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _refreshing ? null : _refreshCourses,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: _refreshing
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 19,
                            color: theme.colorScheme.primary,
                          ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];

      return isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: headerContent,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: headerContent,
            );
    });
  }

  // ============================================================
  // COURSE GRID
  // ============================================================

  Widget _buildCourseGrid(
      List<CourseModel> courses,
      ) {
    return LayoutBuilder(
      builder:
          (
          context,
          constraints,
          ) {
        int columns;

        if (constraints.maxWidth >=
            1350) {
          columns = 3;
        } else if (constraints.maxWidth >=
            850) {
          columns = 2;
        } else {
          columns = 1;
        }

        return GridView.builder(
          shrinkWrap: true,

          physics:
          const NeverScrollableScrollPhysics(),

          gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
            columns,

            crossAxisSpacing:
            24,

            mainAxisSpacing:
            24,

            mainAxisExtent:
            400,
          ),

          itemCount:
          courses.length,

          itemBuilder:
              (
              context,
              index,
              ) {
            final course =
            courses[index];

            final data =
                _progressMap[
                course.id] ??
                    {};

            final progress =
            (data['progress'] ??
                0)
                .toDouble();

            final lessonsCount =
            (data['lessons'] ??
                0) as int;

            final duration =
            (data['duration'] ??
                0) as int;

            return CourseCard(
              course:
              course,

              progress:
              progress,

              lessonsCount:
              lessonsCount,

              duration:
              duration,

              onPressed: () {
                _openCourse(
                  course,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class _CoursesLoading
    extends StatelessWidget {
  const _CoursesLoading();

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Container(
      color:
      theme.colorScheme.surface,

      child:
      Center(
        child:
        CircularProgressIndicator(
          color:
          theme.colorScheme.primary,
        ),
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _CoursesError
    extends StatelessWidget {
  final String message;

  final VoidCallback onRetry;

  const _CoursesError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Container(
      color:
      theme.colorScheme.surface,

      child:
      Center(
        child:
        Container(
          constraints:
          const BoxConstraints(
            maxWidth: 500,
          ),

          margin:
          const EdgeInsets.all(
            24,
          ),

          padding:
          const EdgeInsets.all(
            32,
          ),

          decoration:
          BoxDecoration(
            color:
            theme.cardTheme.color,

            borderRadius:
            BorderRadius.circular(
              16,
            ),

            border:
            Border.all(
              color:
              theme.dividerColor,
            ),
          ),

          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              Container(
                width: 56,
                height: 56,

                decoration:
                BoxDecoration(
                  color:
                  Colors.red.withValues(
                    alpha: 0.08,
                  ),

                  shape:
                  BoxShape.circle,
                ),

                child:
                const Icon(
                  Icons.error_outline,

                  size: 30,

                  color:
                  Colors.redAccent,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              Text(
                'Unable to load courses',

                style:
                TextStyle(
                  fontSize: 19,

                  fontWeight:
                  FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                message,

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),

                  fontSize: 13,
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              ElevatedButton.icon(
                onPressed:
                onRetry,

                icon:
                const Icon(
                  Icons.refresh,
                  size: 18,
                ),

                label:
                const Text(
                  'Retry',
                ),

                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  theme.colorScheme.primary,

                  foregroundColor:
                  Colors.white,

                  elevation: 0,

                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyCoursesState
    extends StatelessWidget {
  const _EmptyCoursesState();

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Container(
      color:
      theme.colorScheme.surface,

      child:
      Center(
        child:
        Container(
          constraints:
          const BoxConstraints(
            maxWidth: 460,
          ),

          padding:
          const EdgeInsets.all(
            40,
          ),

          margin:
          const EdgeInsets.all(
            24,
          ),

          decoration:
          BoxDecoration(
            color:
            theme.cardTheme.color,

            borderRadius:
            BorderRadius.circular(
              18,
            ),

            border:
            Border.all(
              color:
              theme.dividerColor,
            ),
          ),

          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              Container(
                width: 70,
                height: 70,

                decoration:
                BoxDecoration(
                  color:
                  theme.colorScheme.primary.withValues(
                    alpha: 0.07,
                  ),

                  shape:
                  BoxShape.circle,
                ),

                child:
                Icon(
                  Icons.menu_book_outlined,

                  size: 34,

                  color:
                  theme.colorScheme.primary,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                'No courses available',

                style:
                TextStyle(
                  fontSize: 20,

                  fontWeight:
                  FontWeight.w700,

                  color:
                  theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'Training courses will appear here when they become available.',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  fontSize: 13,

                  color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),

                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
