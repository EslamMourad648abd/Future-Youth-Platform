class AgentTrainingAnalyticsModel {
  final String userId;
  final String userName;
  final int totalCourses;
  final int completedCourses;
  final double overallProgress;
  final double averageQuizScore;
  final List<CourseAnalyticsModel> courses;
  const AgentTrainingAnalyticsModel({
    required this.userId,
    required this.userName,
    required this.totalCourses,
    required this.completedCourses,
    required this.overallProgress,
    required this.averageQuizScore,
    required this.courses,
  });
}
class CourseAnalyticsModel {
  final String courseId;
  final String courseName;
  final int totalLessons;
  final int completedLessons;
  final double progress;
  final double quizScore;
  final bool completed;
  // ============================================================
  // CERTIFICATE
  // ============================================================
  final bool certificateIssued;
  final String? certificateUrl;
  final DateTime? certificateIssuedAt;
  const CourseAnalyticsModel({
    required this.courseId,
    required this.courseName,
    required this.totalLessons,
    required this.completedLessons,
    required this.progress,
    required this.quizScore,
    required this.completed,
    required this.certificateIssued,
    required this.certificateUrl,
    required this.certificateIssuedAt,
  });
}