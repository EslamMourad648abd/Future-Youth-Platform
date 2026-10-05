import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../admin_console/services/training_admin_service.dart';
import '../../../router/app_router.dart';
import '../models/quiz_model.dart';
import '../models/quiz_question_model.dart';
import '../services/training_progress_service.dart';

class QuizScreen extends StatefulWidget {
  final String courseId;
  final String lessonId;

  const QuizScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  @override
  State<QuizScreen> createState() =>
      _QuizScreenState();
}

class _QuizScreenState
    extends State<QuizScreen> {
  final TrainingAdminService
  adminService =
  TrainingAdminService();

  final TrainingProgressService
  progressService =
  TrainingProgressService();

  QuizModel? quiz;

  bool loading = true;

  bool submitting = false;

  int currentIndex = 0;

  List<int?> selectedAnswers = [];

  bool alreadySubmitted = false;

  @override
  void initState() {
    super.initState();

    _loadQuiz();
  }

  // ============================================================
  // LOAD QUIZ
  // ============================================================

  Future<void> _loadQuiz() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user != null) {
        alreadySubmitted =
        await progressService
            .isQuizSubmitted(
          userId: user.uid,
          courseId:
          widget.courseId,
          lessonId:
          widget.lessonId,
        );
      }

      final result =
      await adminService.getQuiz(
        courseId:
        widget.courseId,
        lessonId:
        widget.lessonId,
      );

      if (!mounted) return;

      if (alreadySubmitted) {
        setState(() {
          quiz = result;
          loading = false;
        });

        return;
      }

      if (result != null &&
          result.questions.isNotEmpty) {
        quiz = result;

        selectedAnswers =
            List.generate(
              result.questions.length,
                  (_) => null,
            );
      } else {
        quiz = result;
      }

      setState(() {
        loading = false;
      });
    } catch (e) {
      debugPrint(
        "QUIZ LOAD ERROR: $e",
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            "Failed to load quiz: $e",
          ),
          backgroundColor:
          Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submitQuiz() async {
    if (quiz == null ||
        submitting ||
        alreadySubmitted) {
      return;
    }

    if (selectedAnswers.contains(null)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text(
            "Please answer all questions",
          ),
        ),
      );

      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      submitting = true;
    });

    try {
      int correct = 0;

      final List<Map<String, dynamic>>
      answers = [];

      for (int i = 0;
      i < quiz!.questions.length;
      i++) {
        final QuizQuestionModel
        question =
        quiz!.questions[i];

        final selected =
        selectedAnswers[i]!;

        if (selected ==
            question
                .correctAnswerIndex) {
          correct++;
        }

        answers.add({
          "questionId":
          question.id,
          "selectedAnswer":
          selected,
          "correctAnswer":
          question
              .correctAnswerIndex,
        });
      }

      final score =
      ((correct /
          quiz!.questions
              .length) *
          100)
          .round();

      final passed =
          score >=
              quiz!.passingScore;

      await progressService
          .submitQuiz(
        userId: user.uid,
        courseId:
        widget.courseId,
        lessonId:
        widget.lessonId,
        score: score,
        passed: passed,
        answers: answers,
      );

      if (!mounted) return;

      setState(() {
        submitting = false;
        alreadySubmitted = true;
      });

      // --------------------------------------------------------
      // OPEN REVIEW
      //
      // IMPORTANT:
      // Push the review screen instead of replacing the quiz.
      //
      // Stack:
      //
      // CourseDetails
      //      ↓
      // LessonScreen
      //      ↓
      // QuizScreen
      //      ↓
      // QuizReviewScreen
      //
      // Closing review returns to QuizScreen.
      // Back from QuizScreen then returns to LessonScreen.
      // --------------------------------------------------------

      final reviewPath =
      AppRouter.quizReviewPath(
        widget.courseId,
        widget.lessonId,
      );

      debugPrint('================================');
      debugPrint('QUIZ SUBMITTED');
      debugPrint(
        'COURSE ID: ${widget.courseId}',
      );
      debugPrint(
        'LESSON ID: ${widget.lessonId}',
      );
      debugPrint(
        'REVIEW ROUTE: $reviewPath',
      );
      debugPrint(
        'CURRENT URL: '
            '${GoRouterState.of(context).uri}',
      );
      debugPrint('================================');

      await context.push(reviewPath);
    } catch (e) {
      debugPrint(
        "QUIZ SUBMIT ERROR: $e",
      );

      if (!mounted) return;

      setState(() {
        submitting = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            "Failed to submit quiz: $e",
          ),
          backgroundColor:
          Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    if (loading) {
      return Scaffold(
        backgroundColor:
        theme.colorScheme.surface,
        body: Center(
          child:
          CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (alreadySubmitted) {
      return _buildAlreadySubmitted(context);
    }

    if (quiz == null) {
      return Scaffold(
        backgroundColor:
        theme.colorScheme.surface,
        body: Center(
          child:
          Text(
            "Quiz not available",
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor:
        theme.colorScheme.primary,
        foregroundColor:
        theme.colorScheme.onPrimary,
        title:
        const Text(
          "Lesson Quiz",
        ),
        leading:
        IconButton(
          onPressed: () {
            context.pop();
          },
          icon:
          const Icon(
            Icons.arrow_back,
          ),
        ),
      ),
      body:
      _buildQuiz(context),
    );
  }

  // ============================================================
  // ALREADY SUBMITTED
  // ============================================================

  Widget _buildAlreadySubmitted(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor:
      theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor:
        theme.colorScheme.primary,
        foregroundColor:
        theme.colorScheme.onPrimary,
        title:
        const Text(
          "Lesson Quiz",
        ),
        leading:
        IconButton(
          onPressed: () {
            context.pop();
          },
          icon:
          const Icon(
            Icons.arrow_back,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding:
          const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                size: 70,
                color:
                Colors.green,
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                "Quiz Already Submitted",
                style:
                TextStyle(
                  fontSize: 24,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                "This quiz has already been submitted. You can review your answers.",
                textAlign:
                TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
              ),
              const SizedBox(
                height: 25,
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final reviewPath =
                  AppRouter
                      .quizReviewPath(
                    widget.courseId,
                    widget.lessonId,
                  );

                  await context.push(
                    reviewPath,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                icon:
                const Icon(
                  Icons.visibility,
                ),
                label:
                const Text(
                  "Review Quiz",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QUIZ
  // ============================================================

  Widget _buildQuiz(BuildContext context) {
    final theme = Theme.of(context);
    if (quiz!.questions.isEmpty) {
      return Center(
        child:
        Text(
          "This quiz has no questions.",
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
      );
    }

    final question =
    quiz!.questions[
    currentIndex];

    return Padding(
      padding:
      const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            "Question ${currentIndex + 1} / "
                "${quiz!.questions.length}",
            style:
            TextStyle(
              color:
              theme.colorScheme.primary,
              fontSize: 16,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          LinearProgressIndicator(
            value:
            (currentIndex + 1) /
                quiz!.questions.length,
            minHeight: 7,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            color: theme.colorScheme.primary,
          ),
          const SizedBox(
            height: 20,
          ),
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(22),
            decoration:
            BoxDecoration(
              color: theme.cardTheme.color,
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
            Text(
              question.question,
              style:
              TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          ...List.generate(
            question.options.length,
                (index) {
              final selected =
                  selectedAnswers[
                  currentIndex] ==
                      index;

              return GestureDetector(
                onTap: () {
                  if (submitting) {
                    return;
                  }

                  setState(() {
                    selectedAnswers[
                    currentIndex] =
                        index;
                  });
                },
                child:
                Container(
                  margin:
                  const EdgeInsets.only(
                    bottom: 12,
                  ),
                  padding:
                  const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                  BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.cardTheme.color,
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                    border:
                    Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                    ),
                  ),
                  child:
                  Row(
                    children: [
                      Icon(
                        selected
                            ? Icons
                            .radio_button_checked
                            : Icons
                            .radio_button_off,
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                        Text(
                          question
                              .options[index],
                          style:
                          TextStyle(
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
            children: [
              ElevatedButton(
                onPressed:
                currentIndex == 0 ||
                    submitting
                    ? null
                    : () {
                  setState(() {
                    currentIndex--;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.cardTheme.color,
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.dividerColor),
                ),
                child:
                const Text(
                  "Previous",
                ),
              ),
              currentIndex ==
                  quiz!.questions
                      .length -
                      1
                  ? ElevatedButton.icon(
                onPressed:
                submitting
                    ? null
                    : _submitQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                icon:
                submitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                    color:
                    Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.check,
                ),
                label:
                Text(
                  submitting
                      ? "Submitting..."
                      : "Submit Quiz",
                ),
              )
                  : ElevatedButton(
                onPressed:
                submitting
                    ? null
                    : () {
                  setState(() {
                    currentIndex++;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child:
                const Text(
                  "Next",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}