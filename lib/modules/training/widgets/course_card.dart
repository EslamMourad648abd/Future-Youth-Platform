import 'package:flutter/material.dart';
import '../models/course_model.dart';

class CourseCard extends StatefulWidget {
  final CourseModel course;
  final VoidCallback onPressed;
  final double progress;
  final int lessonsCount;

  /// Total course duration in seconds.
  final int duration;

  const CourseCard({
    super.key,
    required this.course,
    required this.onPressed,
    required this.progress,
    required this.lessonsCount,
    required this.duration,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  bool _hovering = false;

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) {
      return "0:00";
    }

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final progressPercentage = widget.progress.round();
    final theme = Theme.of(context);

    final formattedDuration =
    _formatDuration(widget.duration);

    String buttonText;

    if (progressPercentage == 0) {
      buttonText = "Start Course";
    } else if (progressPercentage >= 100) {
      buttonText = "Review Course";
    } else {
      buttonText = "Continue Learning";
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,

      onEnter: (_) {
        setState(() {
          _hovering = true;
        });
      },

      onExit: (_) {
        setState(() {
          _hovering = false;
        });
      },

      child: AnimatedScale(
        duration: const Duration(
          milliseconds: 180,
        ),
        scale: _hovering ? 1.02 : 1.0,

        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),

          decoration: BoxDecoration(
            color: theme.cardTheme.color,

            borderRadius:
            BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: _hovering ? .15 : .08,
                ),
                blurRadius:
                _hovering ? 18 : 10,
                offset:
                const Offset(0, 6),
              ),
            ],
          ),

          child: Padding(
            padding: const EdgeInsets.all(24),

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              mainAxisSize: MainAxisSize.min,

              children: [
                // ==================================================
                // ICON
                // ==================================================

                Center(
                  child: CircleAvatar(
                    radius: 34,

                    backgroundColor:
                    theme.colorScheme.primary
                        .withValues(alpha: .08),

                    child: Icon(
                      Icons.school,
                      size: 34,
                      color:
                      theme.colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // TITLE
                // ==================================================

                Text(
                  widget.course.title,

                  maxLines: 2,

                  overflow:
                  TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    theme.colorScheme.primary,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                // ==================================================
                // DESCRIPTION
                // ==================================================

                Text(
                  widget.course.description,

                  maxLines: 3,

                  overflow:
                  TextOverflow.ellipsis,

                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // COURSE INFO
                // ==================================================

                Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      size: 18,
                      color:
                      theme.colorScheme.primary,
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    Flexible(
                      child: Text(
                        "${widget.lessonsCount} Lessons",
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Icon(
                      Icons.schedule,
                      size: 18,
                      color:
                      theme.colorScheme.primary,
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    Text(
                      formattedDuration,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                // ==================================================
                // PROGRESS TITLE
                // ==================================================

                Text(
                  "Progress",

                  style: TextStyle(
                    fontWeight:
                    FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                // ==================================================
                // PROGRESS BAR
                // ==================================================

                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(20),

                  child:
                  LinearProgressIndicator(
                    value:
                    widget.progress <= 0
                        ? 0
                        : widget.progress >= 100
                        ? 1
                        : widget.progress / 100,

                    minHeight: 8,

                    backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),

                    valueColor:
                    AlwaysStoppedAnimation(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                // ==================================================
                // PROGRESS PERCENTAGE
                // ==================================================

                Align(
                  alignment:
                  Alignment.centerRight,

                  child: Text(
                    "$progressPercentage%",

                    style: TextStyle(
                      color:
                      theme.colorScheme.primary,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // ACTION BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed:
                    widget.onPressed,

                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      theme.colorScheme.primary,

                      foregroundColor:
                      theme.colorScheme.onPrimary,

                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 15,
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),

                    child: Text(
                      buttonText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}