class UserProgressModel {

  final String courseId;

  final double progress;

  final int completedLessons;

  final bool completed;

  final double quizScore;

  const UserProgressModel({

    required this.courseId,
    required this.progress,
    required this.completedLessons,
    required this.completed,
    required this.quizScore,

  });

}