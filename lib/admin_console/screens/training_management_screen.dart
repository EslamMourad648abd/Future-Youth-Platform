import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../modules/training/models/course_model.dart';
import '../../modules/training/repositories/firebase_training_repository.dart';

import 'lesson_management_screen.dart';
import '../services/training_admin_service.dart';
import '../widgets/course_admin_card.dart';
import '../widgets/course_form_dialog.dart';

class TrainingManagement extends StatefulWidget {
  const TrainingManagement({
    super.key, required FirebaseFunctions functions,
  });

  @override
  State<TrainingManagement> createState() =>
      _TrainingManagementState();
}

class _TrainingManagementState
    extends State<TrainingManagement> {
  final FirebaseTrainingRepository repository =
  FirebaseTrainingRepository();

  final TrainingAdminService adminService =
  TrainingAdminService();

  List<CourseModel> courses = [];

  bool loading = true;

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
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final result =
      await repository.getCourses();

      if (!mounted) return;

      setState(() {
        courses = result;
        loading = false;
      });
    } catch (e) {
      debugPrint(
        "LOAD COURSES ERROR: $e",
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to load courses: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ADD COURSE
  // ============================================================

  Future<void> _showAddCourseDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return CourseFormDialog(
          onSave: (data) async {
            try {
              await adminService.addCourse(
                title:
                data["title"] ?? "",
                description:
                data["description"] ?? "",
                driveFolderId:
                data["driveFolderId"] ?? "",
                driveFolderUrl:
                data["driveFolderUrl"] ?? "",
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              await _loadCourses();

              if (!mounted) return;

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    "Course added successfully.",
                  ),
                  backgroundColor:
                  Colors.green,
                ),
              );
            } catch (e) {
              debugPrint(
                "ADD COURSE ERROR: $e",
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                SnackBar(
                  content: Text(
                    "Failed to add course: $e",
                  ),
                  backgroundColor:
                  Colors.red,
                ),
              );
            }
          },
        );
      },
    );
  }

  // ============================================================
  // EDIT COURSE
  // ============================================================

  Future<void> _showEditCourseDialog(
      CourseModel course,
      ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return CourseFormDialog(
          initialData: {
            "title":
            course.title,
            "description":
            course.description,
            "driveFolderId":
            course.driveFolderId,
            "driveFolderUrl":
            course.driveFolderUrl,
          },
          onSave: (data) async {
            try {
              await adminService.updateCourse(
                course.id,
                {
                  "title":
                  data["title"] ?? "",
                  "description":
                  data["description"] ?? "",
                  "driveFolderId":
                  data["driveFolderId"] ?? "",
                  "driveFolderUrl":
                  data["driveFolderUrl"] ?? "",
                },
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              await _loadCourses();

              if (!mounted) return;

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    "Course updated successfully.",
                  ),
                  backgroundColor:
                  Colors.green,
                ),
              );
            } catch (e) {
              debugPrint(
                "UPDATE COURSE ERROR: $e",
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                SnackBar(
                  content: Text(
                    "Failed to update course: $e",
                  ),
                  backgroundColor:
                  Colors.red,
                ),
              );
            }
          },
        );
      },
    );
  }

  // ============================================================
  // DELETE COURSE
  // ============================================================

  Future<void> _deleteCourse(
      CourseModel course,
      ) async {
    final confirm =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Delete Course",
          ),
          content: Text(
            "Are you sure you want to delete '${course.title}'?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.red,
                foregroundColor:
                Colors.white,
              ),
              child: const Text(
                "Delete",
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await adminService.deleteCourse(
        course.id,
      );

      await _loadCourses();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Course deleted successfully.",
          ),
          backgroundColor:
          Colors.green,
        ),
      );
    } catch (e) {
      debugPrint(
        "DELETE COURSE ERROR: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Failed to delete course: $e",
          ),
          backgroundColor:
          Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // MANAGE LESSONS
  // ============================================================

  Future<void> _manageLessons(
      CourseModel course,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LessonManagementScreen(
              course: course,
            ),
      ),
    );

    if (!mounted) return;

    // Refresh course list because lesson count
    // may have changed.
    await _loadCourses();
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

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "Training Management",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        actions: [
          IconButton(
            tooltip:
            "Refresh Courses",
            onPressed: loading
                ? null
                : _loadCourses,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),

      // ========================================================
      // ADD COURSE BUTTON
      // ========================================================

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed:
        _showAddCourseDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          "Add Course",
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _buildBody(context),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    // Loading
    if (loading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    // Empty
    if (courses.isEmpty) {
      return Center(
        child: Padding(
          padding:
          const EdgeInsets.all(
            32,
          ),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 70,
                color:
                theme.colorScheme.primary.withValues(alpha: 0.5),
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                "No Courses Yet",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                "Create your first training course to start adding lessons.",
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              ElevatedButton.icon(
                onPressed:
                _showAddCourseDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(
                  Icons.add,
                ),
                label: const Text(
                  "Add Course",
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Course List
    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: ListView.builder(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.all(
          24,
        ),
        itemCount:
        courses.length,
        itemBuilder:
            (context, index) {
          final course =
          courses[index];

          return CourseAdminCard(
            course: course,

            // ================================================
            // EDIT
            // ================================================

            onEdit: () {
              _showEditCourseDialog(
                course,
              );
            },

            // ================================================
            // DELETE
            // ================================================

            onDelete: () {
              _deleteCourse(
                course,
              );
            },

            // ================================================
            // MANAGE LESSONS
            // ================================================

            onManageLessons: () {
              _manageLessons(
                course,
              );
            },
          );
        },
      ),
    );
  }
}