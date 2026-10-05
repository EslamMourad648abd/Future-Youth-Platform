import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../modules/training/models/agent_training_analytics_model.dart';

class AgentTrainingDetailsScreen extends StatelessWidget {
  final AgentTrainingAnalyticsModel agent;

  const AgentTrainingDetailsScreen({
    super.key,
    required this.agent,
  });

  // ============================================================
  // OPEN CERTIFICATE POPUP
  // ============================================================

  Future<void> _openCertificate(
      BuildContext context,
      String url,
      ) async {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Certificate URL is not available."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid certificate URL."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ------------------------------------------------------------
    // Unique view type for this certificate iframe.
    // ------------------------------------------------------------

    final viewType =
        'certificate-pdf-${DateTime.now().microsecondsSinceEpoch}';

    bool isLoaded = false;

    // ------------------------------------------------------------
    // Register the browser iframe.
    // ------------------------------------------------------------

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
          (int viewId) {
        final iframe = html.IFrameElement()
          ..src = uri.toString()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'block'
          ..style.backgroundColor = 'white'
          ..setAttribute('allowfullscreen', 'true');

        iframe.onLoad.listen((_) {
          isLoaded = true;
        });

        return iframe;
      },
    );

    // ------------------------------------------------------------
    // Show certificate popup.
    // ------------------------------------------------------------

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            // ----------------------------------------------------
            // Give the iframe a little time to initialize.
            //
            // The actual browser PDF viewer is responsible for
            // rendering the certificate.
            // ----------------------------------------------------

            if (!isLoaded) {
              Future.delayed(
                const Duration(milliseconds: 300),
                    () {
                  if (dialogContext.mounted) {
                    setDialogState(() {});
                  }
                },
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              child: LayoutBuilder(
                builder: (
                    context,
                    constraints,
                    ) {
                  final screenWidth =
                      MediaQuery.of(context).size.width;

                  final screenHeight =
                      MediaQuery.of(context).size.height;

                  final dialogWidth =
                  screenWidth > 1150
                      ? 1100.0
                      : screenWidth - 36;

                  final dialogHeight =
                  screenHeight > 850
                      ? 800.0
                      : screenHeight - 36;

                  return Container(
                    width: dialogWidth,
                    height: dialogHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xffF5F1F8),
                      borderRadius:
                      BorderRadius.circular(22),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // ==================================================
                        // POPUP HEADER
                        // ==================================================

                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            24,
                            18,
                            18,
                            14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color:
                                  const Color(0xffE8F2FC),
                                  borderRadius:
                                  BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.workspace_premium,
                                  color:
                                  Color(0xff003366),
                                  size: 28,
                                ),
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Course Completed",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight:
                                        FontWeight.bold,
                                        color:
                                        Color(0xff003366),
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      _getCourseNameFromUrl(
                                        url,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                        Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                tooltip: "Close",
                                onPressed: () {
                                  Navigator.of(
                                    dialogContext,
                                  ).pop();
                                },
                                icon: const Icon(
                                  Icons.close,
                                  size: 25,
                                  color:
                                  Color(0xff4A4A4A),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ==================================================
                        // CERTIFICATE VIEWER
                        // ==================================================

                        Expanded(
                          child: Padding(
                            padding:
                            const EdgeInsets.fromLTRB(
                              24,
                              4,
                              24,
                              18,
                            ),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                  const Color(0xffDCE5EE),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.08),
                                    blurRadius: 14,
                                    offset:
                                    const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior:
                              Clip.antiAlias,
                              child: Stack(
                                children: [
                                  // ------------------------------------------------
                                  // Embedded PDF
                                  // ------------------------------------------------

                                  Positioned.fill(
                                    child: HtmlElementView(
                                      viewType: viewType,
                                    ),
                                  ),

                                  // ------------------------------------------------
                                  // Loading overlay
                                  // ------------------------------------------------

                                  if (!isLoaded)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.white,
                                        child: Column(
                                          mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,
                                          children: [
                                            const SizedBox(
                                              width: 38,
                                              height: 38,
                                              child:
                                              CircularProgressIndicator(
                                                strokeWidth: 3,
                                                color:
                                                Color(
                                                  0xff003366,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(
                                              height: 16,
                                            ),

                                            Text(
                                              "Loading certificate...",
                                              style:
                                              TextStyle(
                                                fontSize: 15,
                                                fontWeight:
                                                FontWeight
                                                    .w500,
                                                color: Colors
                                                    .grey
                                                    .shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ==================================================
                        // CLOSE
                        // ==================================================

                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 16,
                          ),
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(
                                dialogContext,
                              ).pop();
                            },
                            child: const Text(
                              "Close",
                              style: TextStyle(
                                fontSize: 15,
                                color:
                                Color(0xff7550B8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // COURSE NAME HELPER
  // ============================================================
  //
  // The analytics model already contains the course name, but
  // _openCertificate currently receives only the URL.
  //
  // This method intentionally returns an empty string when the
  // course name cannot be determined from the URL.
  //
  // The actual course name is displayed by the course card.
  // ============================================================

  String _getCourseNameFromUrl(String url) {
    return "Certificate";
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          agent.userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _summaryCard(context),
              const SizedBox(height: 20),
              Text(
                "Courses",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...agent.courses.map((course) => _courseCard(context, course)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _summaryCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              "Training Summary",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            _infoRow("Total Courses", agent.totalCourses.toString(), theme),
            _infoRow("Completed Courses", agent.completedCourses.toString(), theme),
            _infoRow("Overall Progress", "${agent.overallProgress.toStringAsFixed(1)}%", theme),
            _infoRow("Average Quiz Score", "${agent.averageQuizScore.toStringAsFixed(1)}%", theme),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================================
  // COURSE CARD
  // ============================================================

  Widget _courseCard(
      BuildContext context,
      CourseAnalyticsModel course,
      ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(
        bottom: 15,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              course.courseName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            _courseStat("Lessons", "${course.completedLessons}/${course.totalLessons}", theme),
            _courseStat("Progress", "${course.progress.toStringAsFixed(1)}%", theme),
            _courseStat("Quiz Score", "${course.quizScore.toStringAsFixed(1)}%", theme),

            const SizedBox(
              height: 8,
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (course.completed ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                course.completed
                    ? "Completed"
                    : "In Progress",
                style: TextStyle(
                  color: course.completed
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),

            // ----------------------------------------------------
            // CERTIFICATE
            // ----------------------------------------------------

            if (course.certificateIssued &&
                course.certificateUrl != null) ...[
              const SizedBox(
                height: 15,
              ),

              Divider(color: theme.dividerColor),

              const SizedBox(
                height: 10,
              ),

              Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: theme.colorScheme.primary,
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Text(
                      "Certificate Issued",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  TextButton.icon(
                    onPressed: () {
                      _openCertificate(
                        context,
                        course.certificateUrl!,
                      );
                    },
                    icon: const Icon(
                      Icons.visibility_outlined,
                    ),
                    label: const Text(
                      "View",
                    ),
                  ),
                ],
              ),

              if (course.certificateIssuedAt !=
                  null)
                Text(
                  "Issued: "
                      "${_formatDate(course.certificateIssuedAt!)}",
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _courseStat(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(
      DateTime date,
      ) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }
}