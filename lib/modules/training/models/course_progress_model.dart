class CourseProgressModel {

  final int totalLessons;

  final int completedLessons;

  final int completedVideos;

  final int submittedQuizzes;

  final double progressPercentage;


  // ============================================================
  // PHASE 2 ANALYTICS FIELDS
  // ============================================================

  final double averageQuizScore;

  final bool courseCompleted;

  final DateTime? completedAt;



  const CourseProgressModel({

    required this.totalLessons,

    required this.completedLessons,

    required this.completedVideos,

    required this.submittedQuizzes,

    required this.progressPercentage,


    required this.averageQuizScore,

    required this.courseCompleted,

    required this.completedAt,

  });


}