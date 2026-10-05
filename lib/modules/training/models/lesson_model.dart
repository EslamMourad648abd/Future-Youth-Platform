

class LessonModel {


  final String id;

  final String courseId;

  final String title;

  final String description;

  final String videoUrl;

  final int duration;

  final int order;

  final bool quizEnabled;



  const LessonModel({

    required this.id,

    required this.courseId,

    required this.title,

    required this.description,

    required this.videoUrl,

    required this.duration,

    required this.order,

    required this.quizEnabled,

  });





  factory LessonModel.fromMap(

      Map<String, dynamic> data,

      String id,

      ) {


    return LessonModel(

      id: id,


      courseId:
      data["courseId"] ?? "",


      title:
      data["title"] ?? "",


      description:
      data["description"] ?? "",


      videoUrl:
      data["videoUrl"] ?? "",


      duration:
      data["duration"] is int
          ? data["duration"]
          : 0,


      order:
      data["order"] is int
          ? data["order"]
          : 0,


      quizEnabled:
      data["quizEnabled"] ?? false,


    );


  }





  Map<String, dynamic> toMap(){


    return {


      "courseId":
      courseId,


      "title":
      title,


      "description":
      description,


      "videoUrl":
      videoUrl,


      "duration":
      duration,


      "order":
      order,


      "quizEnabled":
      quizEnabled,


    };


  }



}