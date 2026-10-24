import '../models/course_model.dart';

class TrainingCourses {
  static const List<CourseModel> courses = [];

  /// Total number of courses
  static int get totalCourses => courses.length;

  /// Total duration in minutes
  static int get totalDuration => courses.fold(
        0,
        (sum, course) => sum + course.duration,
      );

  static double get overallProgress => 0;
}
