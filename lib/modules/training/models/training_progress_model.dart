class LessonProgressModel {

  final String lessonId;

  final bool videoCompleted;

  final DateTime? videoCompletedAt;


  final bool quizSubmitted;

  final int quizScore;

  final bool quizPassed;

  final DateTime? submittedAt;


  final DateTime? completedAt;


  const LessonProgressModel({

    required this.lessonId,

    required this.videoCompleted,

    required this.videoCompletedAt,

    required this.quizSubmitted,

    required this.quizScore,

    required this.quizPassed,

    required this.submittedAt,

    required this.completedAt,

  });


  factory LessonProgressModel.fromMap(
      String id,
      Map<String,dynamic> data,
      ){

    return LessonProgressModel(

      lessonId:id,


      videoCompleted:
      data["videoCompleted"] ?? false,


      videoCompletedAt:
      data["videoCompletedAt"]?.toDate(),


      quizSubmitted:
      data["quizSubmitted"] ?? false,


      quizScore:
      data["score"] ?? 0,


      quizPassed:
      data["passed"] ?? false,


      submittedAt:
      data["submittedAt"]?.toDate(),


      completedAt:
      data["completedAt"]?.toDate(),

    );

  }


  Map<String,dynamic> toMap(){

    return {

      "videoCompleted":
      videoCompleted,


      "videoCompletedAt":
      videoCompletedAt,


      "quizSubmitted":
      quizSubmitted,


      "score":
      quizScore,


      "passed":
      quizPassed,


      "submittedAt":
      submittedAt,


      "completedAt":
      completedAt,

    };

  }

}