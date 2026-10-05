import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../models/lesson_model.dart';
import '../services/training_progress_service.dart';
import '../widgets/google_drive_player.dart';

class LessonScreen extends StatefulWidget {
  final LessonModel lesson;

  const LessonScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final TrainingProgressService progressService =
  TrainingProgressService();

  bool lessonCompleted = false;
  bool loadingProgress = true;
  bool quizSubmitted = false;
  bool videoCompleted = false;
  bool processingAction = false;

  bool get quizEnabled => widget.lesson.quizEnabled;

  @override
  void initState() {
    super.initState();

    _loadProgress();
  }

  // ============================================================
  // LOAD PROGRESS
  // ============================================================

  Future<void> _loadProgress() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        loadingProgress = false;
      });

      return;
    }

    try {
      final completed = await progressService.isLessonCompleted(
        userId: user.uid,
        courseId: widget.lesson.courseId,
        lessonId: widget.lesson.id,
      );

      final submitted = await progressService.isQuizSubmitted(
        userId: user.uid,
        courseId: widget.lesson.courseId,
        lessonId: widget.lesson.id,
      );

      final video = await progressService.isVideoCompleted(
        userId: user.uid,
        courseId: widget.lesson.courseId,
        lessonId: widget.lesson.id,
      );

      final effectiveCompleted = quizEnabled
          ? completed
          : (completed || video);

      if (!quizEnabled && video && !completed) {
        try {
          await progressService.completeLesson(
            userId: user.uid,
            courseId: widget.lesson.courseId,
            lessonId: widget.lesson.id,
          );
        } catch (e) {
          debugPrint(
            "LESSON COMPLETION SYNC ERROR: $e",
          );
        }
      }

      if (!mounted) return;

      setState(() {
        videoCompleted = video;
        lessonCompleted = effectiveCompleted;
        quizSubmitted = quizEnabled && submitted;
        loadingProgress = false;
      });
    } catch (e) {
      debugPrint(
        "LESSON PROGRESS ERROR: $e",
      );

      if (!mounted) return;

      setState(() {
        loadingProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to load lesson progress: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // COMPLETE LESSON / VIDEO
  // ============================================================

  Future<void> _completeLesson() async {
    if (processingAction) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      processingAction = true;
    });

    try {
      // --------------------------------------------------------
      // VIDEO
      // --------------------------------------------------------

      if (!videoCompleted) {
        await progressService.completeVideo(
          userId: user.uid,
          courseId: widget.lesson.courseId,
          lessonId: widget.lesson.id,
        );

        if (!mounted) return;

        setState(() {
          videoCompleted = true;
        });
      }

      // --------------------------------------------------------
      // QUIZ ENABLED
      // --------------------------------------------------------

      if (quizEnabled) {
        if (!mounted) return;

        final quizPath = AppRouter.quizPath(
          widget.lesson.courseId,
          widget.lesson.id,
        );

        debugPrint('================================');
        debugPrint('OPENING QUIZ');
        debugPrint(
          'COURSE ID: ${widget.lesson.courseId}',
        );
        debugPrint(
          'LESSON ID: ${widget.lesson.id}',
        );
        debugPrint(
          'QUIZ ROUTE: $quizPath',
        );
        debugPrint(
          'CURRENT URL: '
              '${GoRouterState.of(context).uri}',
        );
        debugPrint('================================');

        setState(() {
          processingAction = false;
        });

        // IMPORTANT:
        // Push quiz on top of lesson instead of replacing
        // the current route. This allows the user to return
        // to this lesson and then back to CourseDetails.
        await context.push(quizPath);

        if (!mounted) return;

        await _loadProgress();

        return;
      }

      // --------------------------------------------------------
      // QUIZ DISABLED
      // --------------------------------------------------------

      await progressService.completeLesson(
        userId: user.uid,
        courseId: widget.lesson.courseId,
        lessonId: widget.lesson.id,
      );

      if (!mounted) return;

      await _loadProgress();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Lesson completed successfully",
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        "COMPLETE LESSON ERROR: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to update lesson: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          processingAction = false;
        });
      }
    }
  }

  // ============================================================
  // REVIEW QUIZ
  // ============================================================

  Future<void> _reviewQuiz() async {
    if (!quizEnabled || !quizSubmitted) {
      return;
    }

    final reviewPath = AppRouter.quizReviewPath(
      widget.lesson.courseId,
      widget.lesson.id,
    );

    debugPrint('================================');
    debugPrint('OPENING QUIZ REVIEW');
    debugPrint(
      'COURSE ID: ${widget.lesson.courseId}',
    );
    debugPrint(
      'LESSON ID: ${widget.lesson.id}',
    );
    debugPrint(
      'QUIZ REVIEW ROUTE: $reviewPath',
    );
    debugPrint(
      'CURRENT URL: '
          '${GoRouterState.of(context).uri}',
    );
    debugPrint('================================');

    // IMPORTANT:
    // Push review instead of replacing this lesson.
    await context.push(reviewPath);

    if (!mounted) return;

    await _loadProgress();
  }

  // ============================================================
  // BACK
  // ============================================================

  void _goBack() {
    debugPrint('================================');
    debugPrint('LESSON BACK');
    debugPrint(
      'CURRENT URL: '
          '${GoRouterState.of(context).uri}',
    );
    debugPrint('================================');

    // The new router keeps CourseDetails underneath LessonScreen.
    // Therefore normal pop is now the correct behavior.
    if (context.canPop()) {
      context.pop();
      return;
    }

    // Safety fallback in case the lesson was opened directly.
    context.go(
      AppRouter.coursePath(
        widget.lesson.courseId,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    double lessonProgress = 0;

    String progressText;

    if (lessonCompleted) {
      lessonProgress = 1;
      progressText = "Completed";
    } else if (!quizEnabled) {
      if (videoCompleted) {
        lessonProgress = 1;
        progressText = "Completed";
      } else {
        lessonProgress = 0;
        progressText = "Not completed yet";
      }
    } else if (videoCompleted) {
      lessonProgress = 0.5;
      progressText = "Video completed - Quiz pending";
    } else {
      lessonProgress = 0;
      progressText = "Not completed yet";
    }

    String buttonText;
    IconData buttonIcon;
    VoidCallback? buttonAction;

    if (lessonCompleted) {
      if (quizEnabled && quizSubmitted) {
        buttonText = "Review Quiz";
        buttonIcon = Icons.visibility;
        buttonAction = _reviewQuiz;
      } else {
        buttonText = "Lesson Completed";
        buttonIcon = Icons.check_circle;
        buttonAction = null;
      }
    } else if (!videoCompleted) {
      buttonText = quizEnabled
          ? "Complete Video & Take Quiz"
          : "Complete Video";

      buttonIcon = Icons.play_arrow;
      buttonAction = _completeLesson;
    } else if (quizEnabled) {
      buttonText = "Take Quiz";
      buttonIcon = Icons.quiz;
      buttonAction = _completeLesson;
    } else {
      buttonText = "Complete Lesson";
      buttonIcon = Icons.check;
      buttonAction = _completeLesson;
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(
            Icons.arrow_back,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Training Portal",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            Text(
              lesson.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // VIDEO
                // ==================================================

                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GoogleDrivePlayer(
                      videoUrl: lesson.videoUrl,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // LESSON DESCRIPTION
                // ==================================================

                _buildDescriptionCard(context),

                const SizedBox(height: 20),

                // ==================================================
                // COMPLETION & PROGRESS (Responsive Layout)
                // ==================================================

                LayoutBuilder(builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 700;

                  final completionCard = _buildCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Lesson Completion",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (loadingProgress)
                          CircularProgressIndicator(color: theme.colorScheme.primary)
                        else
                          SizedBox(
                            width: isCompact ? double.infinity : null,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: processingAction ? null : buttonAction,
                              icon: processingAction
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(buttonIcon),
                              label: Text(processingAction ? "Updating..." : buttonText),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );

                  final progressCard = _buildCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Lesson Progress",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 15),
                        LinearProgressIndicator(
                          value: lessonProgress,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          progressText,
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        completionCard,
                        const SizedBox(height: 20),
                        progressCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: completionCard),
                      const SizedBox(width: 20),
                      Expanded(child: progressCard),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LESSON DESCRIPTION CARD
  // ============================================================

  Widget _buildDescriptionCard(BuildContext context) {
    final theme = Theme.of(context);
    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(
                width: 10,
              ),
              Text(
                "Lesson Description",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            widget.lesson.description,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _buildCard(
    BuildContext context, {
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor,
        ),
      ),
      child: child,
    );
  }
}