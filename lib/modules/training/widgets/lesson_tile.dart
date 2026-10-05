import 'package:flutter/material.dart';
import '../models/lesson_model.dart';


class LessonTile extends StatelessWidget {


  final LessonModel lesson;

  final VoidCallback onPressed;


  final bool completed;

  final bool quizSubmitted;

  final bool videoCompleted;



  const LessonTile({

    super.key,

    required this.lesson,

    required this.onPressed,

    this.completed = false,

    this.quizSubmitted = false,

    this.videoCompleted = false,

  });



  @override
  Widget build(BuildContext context) {


    IconData icon;

    Color iconColor;

    String status;



    if(completed || quizSubmitted){


      icon =
          Icons.check_circle;


      iconColor =
          Colors.green;


      status =
      "Completed";


    }

    else if(videoCompleted && lesson.quizEnabled){


      icon =
          Icons.quiz;


      iconColor =
          Colors.orange;


      status =
      "Quiz pending";


    }

    else if(videoCompleted){


      icon =
          Icons.check_circle_outline;


      iconColor =
          Colors.blue;


      status =
      "Video completed";


    }

    else{


      icon =
          Icons.play_arrow;


      iconColor =
      const Color(0xff80CFFF);


      status =
      "Not started";


    }




    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.1),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        title: Text(
          lesson.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          status,
          style: TextStyle(
            color: iconColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        onTap: onPressed,
      ),
    );


  }

}