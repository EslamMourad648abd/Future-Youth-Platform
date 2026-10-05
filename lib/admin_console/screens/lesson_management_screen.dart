import 'package:flutter/material.dart';

import '../../modules/training/models/course_model.dart';
import '../../modules/training/models/lesson_model.dart';
import '../services/training_admin_service.dart';
import '../widgets/lesson_form_dialog.dart';
import '../widgets/quiz_form_dialog.dart';


class LessonManagementScreen extends StatefulWidget {

  final CourseModel course;


  const LessonManagementScreen({
    super.key,
    required this.course,
  });


  @override
  State<LessonManagementScreen> createState() =>
      _LessonManagementScreenState();

}



class _LessonManagementScreenState
    extends State<LessonManagementScreen> {


  final TrainingAdminService adminService =
  TrainingAdminService();


  List lessons = [];


  bool loading = true;



  @override
  void initState() {

    super.initState();

    _loadLessons();

  }



  Future<void> _loadLessons() async {

    setState(() {
      loading = true;
    });


    try {

      lessons = await adminService.getLessons(
        widget.course.id,
      );


    } catch (e) {


      debugPrint(e.toString());


      if (mounted) {

        ScaffoldMessenger.of(context)
            .showSnackBar(

          SnackBar(
            content: Text(
              e.toString(),
            ),
          ),

        );

      }

    }


    if (!mounted) return;


    setState(() {

      loading = false;

    });


  }





  Future<void> _deleteLesson(
      LessonModel lesson,
      ) async {


    await adminService.deleteLesson(
      widget.course.id,
      lesson.id,
    );


    await _loadLessons();


  }






  // ============================================================
  // FORMAT DURATION
  //
  // Firestore stores duration as seconds.
  //
  // Example:
  // 343 seconds -> 5:43
  // ============================================================

  String _formatDuration(int seconds) {

    final minutes = seconds ~/ 60;

    final remainingSeconds = seconds % 60;


    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";

  }







  void _manageQuiz(
      LessonModel lesson,
      ) {


    showDialog(

      context: context,

      builder: (_) => QuizFormDialog(

        courseId:
        widget.course.id,

        lessonId:
        lesson.id,

      ),

    );


  }






  void _showAddDialog() {


    showDialog(

      context: context,


      builder: (_) => LessonFormDialog(

        onSave: (data) async {


          await adminService.addLesson(

            courseId:
            widget.course.id,

            title:
            data["title"],

            description:
            data["description"],

            videoUrl:
            data["videoUrl"],

            duration:
            data["duration"],

            order:
            data["order"],

            quizEnabled:
            data["quizEnabled"],

          );



          if (mounted) {

            Navigator.pop(context);

          }


          await _loadLessons();


        },

      ),

    );


  }







  void _showEditDialog(
      LessonModel lesson,
      ) {


    showDialog(

      context: context,


      builder: (_) => LessonFormDialog(

        initialData:
        lesson.toMap(),


        onSave: (data) async {


          await adminService.updateLesson(

            widget.course.id,

            lesson.id,

            data,

          );



          if (mounted) {

            Navigator.pop(context);

          }



          await _loadLessons();


        },

      ),

    );


  }






  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
      theme.colorScheme.surface,



      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.course.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),



      floatingActionButton:
      FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed:
        _showAddDialog,


        icon:
        const Icon(
          Icons.add,
        ),


        label:
        const Text(
          "Add Lesson",
        ),

      ),





      body: loading


          ?

      const Center(

        child:
        CircularProgressIndicator(),

      )

          : lessons.isEmpty


          ?

      const Center(

        child:

        Text(

          "No lessons added yet.",

          style:

          TextStyle(

            fontSize: 18,

          ),

        ),

      )

          : ListView.builder(


        padding:
        const EdgeInsets.all(20),


        itemCount:
        lessons.length,


        itemBuilder:
            (context,index){


          final LessonModel lesson =
          lessons[index];



          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            color: theme.cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;

              final infoPart = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      lesson.order.toString(),
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lesson.description,
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Text(
                              "Duration: ${_formatDuration(lesson.duration)}",
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                            Text(
                              lesson.quizEnabled ? "Quiz Enabled" : "Quiz Disabled",
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actionsPart = Row(
                mainAxisSize: isCompact ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: isCompact ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (lesson.quizEnabled)
                    IconButton(
                      icon: const Icon(Icons.quiz, color: Colors.green),
                      tooltip: "Manage Quiz",
                      onPressed: () => _manageQuiz(lesson),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showEditDialog(lesson),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteLesson(lesson),
                  ),
                ],
              );

              return Padding(
                padding: const EdgeInsets.all(16),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          infoPart,
                          const Divider(height: 24),
                          actionsPart,
                        ],
                      )
                    : Row(children: [Expanded(child: infoPart), const SizedBox(width: 20), actionsPart]),
              );
            }),
          );


        },

      ),

    );


  }

}