import 'package:flutter/material.dart';
class LessonFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const LessonFormDialog({
    super.key,
    this.initialData,
    required this.onSave,
  });
  @override
  State<LessonFormDialog> createState() =>
      _LessonFormDialogState();
}
class _LessonFormDialogState
    extends State<LessonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController videoUrlController;
  late final TextEditingController durationController;
  late final TextEditingController orderController;
  bool quizEnabled = true;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    titleController = TextEditingController(
      text: data?["title"] ?? "",
    );
    descriptionController = TextEditingController(
      text: data?["description"] ?? "",
    );
    videoUrlController = TextEditingController(
      text: data?["videoUrl"] ?? "",
    );
    // ==========================================================
    // DURATION
    //
    // Firestore stores duration as seconds.
    // The UI displays it as MM:SS.
    //
    // Example:
    // 84 seconds -> 1:24
    // ==========================================================
    durationController = TextEditingController(
      text: _formatDuration(
        data?["duration"],
      ),
    );
    orderController = TextEditingController(
      text: (data?["order"] ?? "").toString(),
    );
    quizEnabled =
        data?["quizEnabled"] ?? true;
  }
  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    videoUrlController.dispose();
    durationController.dispose();
    orderController.dispose();
    super.dispose();
  }
  // ==========================================================
  // FORMAT SECONDS -> MM:SS
  // ==========================================================
  String _formatDuration(dynamic value) {
    if (value == null) {
      return "";
    }
    final seconds = value is int
        ? value
        : int.tryParse(
      value.toString(),
    ) ??
        0;
    if (seconds <= 0) {
      return "";
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
  }
  // ==========================================================
  // PARSE MM:SS -> SECONDS
  // ==========================================================
  int? _parseDuration(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    final parts = text.split(":");
    if (parts.length != 2) {
      return null;
    }
    final minutes = int.tryParse(
      parts[0].trim(),
    );
    final seconds = int.tryParse(
      parts[1].trim(),
    );
    if (minutes == null ||
        seconds == null) {
      return null;
    }
    // Seconds must be between 0 and 59.
    if (minutes < 0 ||
        seconds < 0 ||
        seconds >= 60) {
      return null;
    }
    return (minutes * 60) + seconds;
  }
  // ==========================================================
  // SAVE
  // ==========================================================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final durationInSeconds =
    _parseDuration(
      durationController.text,
    );
    if (durationInSeconds == null) {
      return;
    }
    setState(() {
      saving = true;
    });
    try {
      await widget.onSave({
        "title":
        titleController.text.trim(),
        "description":
        descriptionController.text.trim(),
        "videoUrl":
        videoUrlController.text.trim(),
        // IMPORTANT:
        // Store duration as seconds.
        "duration":
        durationInSeconds,
        "order":
        int.parse(
          orderController.text,
        ),
        "quizEnabled":
        quizEnabled,
      });
    } finally {
      if (!mounted) return;
      setState(() {
        saving = false;
      });
    }
  }
  // ==========================================================
  // INPUT DECORATION
  // ==========================================================
  InputDecoration decoration(
      String label, {
        String? hint,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),
    );
  }
  // ==========================================================
  // BUILD
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      surfaceTintColor: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor),
      ),
      title: Text(
        widget.initialData == null
            ? "Add Lesson"
            : "Edit Lesson",
        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                // ==================================================
                // TITLE
                // ==================================================
                TextFormField(
                  controller:
                  titleController,
                  decoration:
                  decoration(
                    "Title",
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return "Required";
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 16,
                ),
                // ==================================================
                // DESCRIPTION
                // ==================================================
                TextFormField(
                  controller:
                  descriptionController,
                  decoration:
                  decoration(
                    "Description",
                  ),
                  maxLines: 3,
                ),
                const SizedBox(
                  height: 16,
                ),
                // ==================================================
                // VIDEO URL
                // ==================================================
                TextFormField(
                  controller:
                  videoUrlController,
                  decoration:
                  decoration(
                    "Video URL",
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return "Required";
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 16,
                ),
                // ==================================================
                // DURATION
                // ==================================================
                TextFormField(
                  controller:
                  durationController,
                  decoration:
                  decoration(
                    "Duration",
                    hint: "Example: 1:24",
                  ),
                  keyboardType:
                  TextInputType.text,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return "Required";
                    }
                    final duration =
                    _parseDuration(
                      value,
                    );
                    if (duration == null) {
                      return "Use MM:SS format, e.g. 1:24";
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 16,
                ),
                // ==================================================
                // LESSON ORDER
                // ==================================================
                TextFormField(
                  controller:
                  orderController,
                  decoration:
                  decoration(
                    "Lesson Order",
                  ),
                  keyboardType:
                  TextInputType.number,
                  validator: (value) {
                    if (value == null ||
                        int.tryParse(value) ==
                            null) {
                      return "Invalid number";
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 20,
                ),
                // ==================================================
                // QUIZ
                // ==================================================
                SwitchListTile(
                  contentPadding:
                  EdgeInsets.zero,
                  activeColor: theme.colorScheme.primary,
                  title:
                  const Text(
                    "Enable Quiz",
                  ),
                  value:
                  quizEnabled,
                  onChanged: (value) {
                    setState(() {
                      quizEnabled =
                          value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      // ==========================================================
      // ACTIONS
      // ==========================================================
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () {
            Navigator.pop(
              context,
            );
          },
          child:
          Text(
            "Cancel",
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        ElevatedButton(
          onPressed:
          saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: saving
              ? const SizedBox(
            width: 18,
            height: 18,
            child:
            CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text(
            "Save",
          ),
        ),
      ],
    );
  }
}