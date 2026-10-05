import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../models/course_model.dart';
import '../models/lesson_model.dart';
import '../repositories/firebase_training_repository.dart';
import '../services/certificate_service.dart';
import '../widgets/lesson_tile.dart';
import '../widgets/progress_bar.dart';

class CourseDetails extends StatefulWidget {
  final CourseModel course;

  const CourseDetails({
    super.key,
    required this.course,
  });

  @override
  State<CourseDetails> createState() =>
      _CourseDetailsState();
}

class _CourseDetailsState
    extends State<CourseDetails>
    with SingleTickerProviderStateMixin {
  final FirebaseTrainingRepository repository =
  FirebaseTrainingRepository();

  final CertificateService certificateService =
  CertificateService();

  double progress = 0;

  bool loadingProgress = true;

  bool openingCertificate = false;

  List<LessonModel> lessons = [];

  Map<String, Map<String, bool>> lessonProgress = {};

  int totalDuration = 0;

  bool _completionStateInitialized = false;

  bool _previousCourseCompleted = false;

  bool _completionCelebrationShown = false;

  late AnimationController _celebrationController;

  late Animation<double> _scaleAnimation;

  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeOut,
    );

    _loadData();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  // ============================================================
  // DURATION
  // ============================================================

  String _formatDuration(
      int seconds,
      ) {
    final minutes = seconds ~/ 60;

    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadData() async {
    try {
      final loadedLessons = await repository.getLessons(
        widget.course.id,
      );

      int calculatedDuration = 0;

      for (final lesson in loadedLessons) {
        calculatedDuration += lesson.duration;
      }

      final user = FirebaseAuth.instance.currentUser;

      final Map<String, Map<String, bool>> progressMap = {};

      double totalLessonProgress = 0;

      bool celebrationShown = false;

      if (user != null) {
        final progressSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("training_progress")
            .doc(widget.course.id)
            .collection("lessons")
            .get(
          const GetOptions(
            source: Source.server,
          ),
        );

        final Map<String, Map<String, dynamic>>
        firestoreProgress = {};

        for (final doc in progressSnapshot.docs) {
          firestoreProgress[doc.id] = doc.data();
        }

        for (final lesson in loadedLessons) {
          final data = firestoreProgress[lesson.id] ?? {};

          final rawCompleted =
              data["completed"] == true;

          final quizSubmitted =
              data["quizSubmitted"] == true;

          final videoCompleted =
              data["videoCompleted"] == true;

          final effectiveCompleted =
          lesson.quizEnabled
              ? rawCompleted
              : (rawCompleted || videoCompleted);

          double lessonProgressValue = 0;

          if (lesson.quizEnabled) {
            if (videoCompleted) {
              lessonProgressValue += 0.5;
            }

            if (quizSubmitted) {
              lessonProgressValue += 0.5;
            }

            if (rawCompleted) {
              lessonProgressValue = 1;
            }
          } else {
            if (effectiveCompleted) {
              lessonProgressValue = 1;
            }
          }

          totalLessonProgress += lessonProgressValue;

          progressMap[lesson.id] = {
            "completed": effectiveCompleted,
            "quizSubmitted": lesson.quizEnabled
                ? quizSubmitted
                : false,
            "videoCompleted": videoCompleted,
          };
        }

        final courseProgressDoc =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("training_progress")
            .doc(widget.course.id)
            .get(
          const GetOptions(
            source: Source.server,
          ),
        );

        if (courseProgressDoc.exists) {
          final data = courseProgressDoc.data();

          celebrationShown =
              data?["completionCelebrationShown"] ==
                  true;
        }
      }

      final newProgress = loadedLessons.isEmpty
          ? 0.0
          : totalLessonProgress / loadedLessons.length;

      if (!mounted) return;

      setState(() {
        lessons = loadedLessons;

        lessonProgress = progressMap;

        totalDuration = calculatedDuration;

        progress = newProgress;

        loadingProgress = false;

        _completionCelebrationShown =
            celebrationShown;
      });

      _checkCompletionTransition();
    } catch (e) {
      debugPrint(
        "COURSE DETAILS ERROR: $e",
      );

      if (!mounted) return;

      setState(() {
        loadingProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to load course data: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // COMPLETION
  // ============================================================

  bool get _courseCompleted {
    if (lessons.isEmpty) {
      return false;
    }

    for (final lesson in lessons) {
      final status = lessonProgress[lesson.id];

      if (status == null ||
          status["completed"] != true) {
        return false;
      }
    }

    return true;
  }

  void _checkCompletionTransition() {
    if (!mounted) return;

    final currentCompleted = _courseCompleted;

    if (!_completionStateInitialized) {
      _completionStateInitialized = true;

      _previousCourseCompleted = currentCompleted;

      return;
    }

    final justCompleted =
        !_previousCourseCompleted &&
            currentCompleted;

    _previousCourseCompleted = currentCompleted;

    if (!justCompleted ||
        _completionCelebrationShown) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback(
          (_) async {
        if (!mounted) return;

        await _markCelebrationShown();

        if (!mounted) return;

        await _showCompletionPopup(
          firstCompletion: true,
        );
      },
    );
  }

  Future<void> _markCelebrationShown() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("training_progress")
          .doc(widget.course.id)
          .set(
        {
          "completionCelebrationShown": true,
          "completed": true,
          "completedAt":
          FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) return;

      setState(() {
        _completionCelebrationShown = true;
      });
    } catch (e) {
      debugPrint(
        "CELEBRATION FLAG ERROR: $e",
      );
    }
  }

  // ============================================================
  // CERTIFICATE
  // ============================================================

  Future<void> _showCompletionPopup({
    required bool firstCompletion,
  }) async {
    if (openingCertificate) {
      return;
    }

    if (firstCompletion) {
      _celebrationController.reset();

      await _celebrationController.forward();

      if (!mounted) return;
    }

    setState(() {
      openingCertificate = true;
    });

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return _CertificateDialog(
            course: widget.course,
            certificateService: certificateService,
            firstCompletion: firstCompletion,
            scaleAnimation: _scaleAnimation,
            fadeAnimation: _fadeAnimation,
          );
        },
      );
    } finally {
      if (!mounted) return;

      setState(() {
        openingCertificate = false;
      });
    }
  }

  // ============================================================
  // OPEN LESSON
  // ============================================================

  Future<void> _openLesson(
      LessonModel lesson,
      ) async {
    final path = AppRouter.lessonPath(
      widget.course.id,
      lesson.id,
    );

    debugPrint('================================');
    debugPrint('LESSON ID: ${lesson.id}');
    debugPrint('COURSE ID: ${widget.course.id}');
    debugPrint('LESSON ROUTE: $path');
    debugPrint(
      'CURRENT URL: ${GoRouterState.of(context).uri}',
    );
    debugPrint('================================');

    context.go(path);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
      theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor:
        theme.colorScheme.primary,
        foregroundColor:
        theme.colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(
                AppRouter.training,
              );
            }
          },
        ),
        title: Text(
          widget.course.title,
        ),
      ),
      body: loadingProgress
          ? Center(
        child:
        CircularProgressIndicator(color: theme.colorScheme.primary),
      )
          : SingleChildScrollView(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              widget.course.title,
              style: TextStyle(
                fontSize: 28,
                fontWeight:
                FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              widget.course.description,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),

            const SizedBox(
              height: 28,
            ),

            Text(
              "Course Progress",
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            ProgressBar(
              value: progress,
            ),

            const SizedBox(
              height: 30,
            ),

            if (_courseCompleted)
              _buildCertificateCard(context),

            if (_courseCompleted)
              const SizedBox(
                height: 30,
              ),

            LayoutBuilder(builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 500;
              final infoCards = [
                _InfoCard(
                  icon: Icons.menu_book,
                  title: "Lessons",
                  value: lessons.length.toString(),
                  isCompact: isCompact,
                ),
                if (!isCompact) const SizedBox(width: 12),
                if (isCompact) const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.timer,
                  title: "Duration",
                  value: _formatDuration(totalDuration),
                  isCompact: isCompact,
                ),
              ];

              return isCompact
                  ? Column(children: infoCards)
                  : Row(children: infoCards);
            }),

            const SizedBox(
              height: 35,
            ),

            Text(
              "Lessons",
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            if (lessons.isEmpty)
              Padding(
                padding:
                const EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    "No lessons available",
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                itemCount:
                lessons.length,
                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  final lesson =
                  lessons[index];

                  final status =
                      lessonProgress[
                      lesson.id] ??
                          {};

                  return LessonTile(
                    lesson: lesson,
                    completed:
                    status[
                    "completed"] ??
                        false,
                    quizSubmitted:
                    lesson.quizEnabled
                        ? (status[
                    "quizSubmitted"] ??
                        false)
                        : false,
                    videoCompleted:
                    status[
                    "videoCompleted"] ??
                        false,
                    onPressed: () {
                      _openLesson(
                        lesson,
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CERTIFICATE CARD
  // ============================================================

  Widget _buildCertificateCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(22),
      decoration:
      BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium,
                color:
                theme.colorScheme.primary,
                size: 30,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Course Completed!",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    const Text(
                      "Certificate available",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            "Congratulations! You have successfully completed all lessons in this course.",
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),

          const SizedBox(
            height: 18,
          ),

          SizedBox(
            width: double.infinity,
            height: 48,
            child:
            ElevatedButton.icon(
              onPressed:
              openingCertificate
                  ? null
                  : () {
                _showCompletionPopup(
                  firstCompletion:
                  false,
                );
              },
              icon:
              openingCertificate
                  ? const SizedBox(
                width: 20,
                height: 20,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  Colors.white,
                ),
              )
                  : const Icon(
                Icons
                    .workspace_premium,
              ),
              label:
              Text(
                openingCertificate
                    ? "Opening Certificate..."
                    : "View Certificate",
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                theme.colorScheme.primary,
                foregroundColor:
                theme.colorScheme.onPrimary,
                disabledBackgroundColor:
                Colors.grey,
                disabledForegroundColor:
                Colors.white,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CERTIFICATE DIALOG
// ============================================================

class _CertificateDialog
    extends StatefulWidget {
  final CourseModel course;

  final CertificateService
  certificateService;

  final bool firstCompletion;

  final Animation<double>
  scaleAnimation;

  final Animation<double>
  fadeAnimation;

  const _CertificateDialog({
    required this.course,
    required this.certificateService,
    required this.firstCompletion,
    required this.scaleAnimation,
    required this.fadeAnimation,
  });

  @override
  State<_CertificateDialog>
  createState() =>
      _CertificateDialogState();
}

class _CertificateDialogState
    extends State<_CertificateDialog> {
  String? certificateUrl;

  String? certificateViewType;

  bool generating = true;

  String? error;

  @override
  void initState() {
    super.initState();

    _generateCertificate();
  }

  Future<void> _generateCertificate() async {
    try {
      final url = await widget
          .certificateService
          .generateCertificate(
        courseId:
        widget.course.id,
      );

      if (!mounted) return;

      final viewType =
          'certificate-pdf-${DateTime.now().microsecondsSinceEpoch}';

      final iframe =
      html.IFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.outline = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor =
            'white'
        ..allowFullscreen = true;

      ui_web.platformViewRegistry
          .registerViewFactory(
        viewType,
            (int viewId) => iframe,
      );

      setState(() {
        certificateUrl = url;
        certificateViewType =
            viewType;
        generating = false;
      });
    } catch (e) {
      debugPrint(
        "CERTIFICATE POPUP ERROR: $e",
      );

      if (!mounted) return;

      setState(() {
        generating = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.cardTheme.color,
      surfaceTintColor: theme.cardTheme.color,
      elevation: 12,
      insetPadding:
      const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(24),
      ),
      child: SizedBox(
        width:
        MediaQuery.of(context)
            .size
            .width
            .clamp(
          320.0,
          1000.0,
        ),
        height:
        MediaQuery.of(context)
            .size
            .height
            .clamp(
          500.0,
          900.0,
        ) *
            0.88,
        child: Column(
          children: [
            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                24,
                20,
                16,
                14,
              ),
              child: Row(
                children: [
                  widget.firstCompletion
                      ? FadeTransition(
                    opacity:
                    widget
                        .fadeAnimation,
                    child:
                    ScaleTransition(
                      scale:
                      widget
                          .scaleAnimation,
                      child:
                      _buildHeaderIcon(context),
                    ),
                  )
                      : _buildHeaderIcon(context),

                  const SizedBox(
                    width: 14,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.firstCompletion
                              ? "Course Completed!"
                              : "Course Completed",
                          style:
                          TextStyle(
                            fontSize: 23,
                            fontWeight:
                            FontWeight.w700,
                            color:
                            theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          widget.course.title,
                          maxLines: 1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          TextStyle(
                            fontSize: 14,
                            color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed:
                    generating
                        ? null
                        : () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    icon:
                    Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: theme.dividerColor,
            ),

            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  0,
                ),
                child: Column(
                  children: [
                    if (widget.firstCompletion)
                      Padding(
                        padding:
                        const EdgeInsets.only(
                          bottom: 16,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.celebration,
                              size: 20,
                              color:
                              theme.colorScheme.primary,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child: Text(
                                generating
                                    ? "Your certificate is being prepared..."
                                    : "Congratulations! Your certificate is ready.",
                                style:
                                TextStyle(
                                  fontSize: 14,
                                  color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child:
                      _buildCertificateArea(context),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 14,
                      ),
                      child: SizedBox(
                        width:
                        double.infinity,
                        height: 46,
                        child:
                        OutlinedButton(
                          onPressed:
                          generating
                              ? null
                              : () {
                            Navigator.of(
                              context,
                            ).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.dividerColor),
                            foregroundColor: theme.colorScheme.onSurface,
                          ),
                          child:
                          const Text(
                            "Close",
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 54,
      height: 54,
      decoration:
      BoxDecoration(
        color:
        theme.colorScheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child:
      Icon(
        Icons.workspace_premium,
        size: 32,
        color:
        theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildCertificateArea(BuildContext context) {
    final theme = Theme.of(context);
    if (generating) {
      return Container(
        width: double.infinity,
        decoration:
        BoxDecoration(
          color:
          theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius:
          BorderRadius.circular(16),
          border: Border.all(
            color:
            theme.dividerColor,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              SizedBox(
                width: 45,
                height: 45,
                child:
                CircularProgressIndicator(
                  color:
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                "Preparing your certificate",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w600,
                  color:
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Container(
        width: double.infinity,
        decoration:
        BoxDecoration(
          color:
          Colors.red.withValues(alpha: 0.05),
          borderRadius:
          BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                "Unable to load certificate",
                style:
                TextStyle(
                  fontSize: 17,
                  fontWeight:
                  FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (certificateUrl != null &&
        certificateViewType != null) {
      return ClipRRect(
        borderRadius:
        BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          color: Colors.white, // IFrame background is usually white, might look awkward in dark mode but PDF is usually white.
          child:
          HtmlElementView(
            viewType:
            certificateViewType!,
          ),
        ),
      );
    }

    return const SizedBox();
  }
}

// ============================================================
// INFO CARD
// ============================================================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isCompact;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.isCompact = false,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Container(
      width: isCompact ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
