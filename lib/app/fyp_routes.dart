import '../core/constants/user_role.dart';

/// Route paths for the Future Youth Platform. One place, no inline strings.
abstract final class FypRoutes {
  static const String entry = '/';

  // Auth.
  static const String login = '/login/:role';
  static const String signup = '/signup/:role';
  static String loginFor(UserRole role) => '/login/${role.name}';
  static String signupFor(UserRole role) => '/signup/${role.name}';

  // Admin.
  static const String admin = '/admin';
  static const String adminCreateAdmin = '/admin/admins/new';

  // Parent.
  static const String parent = '/parent';
  static const String parentCreateStudent = '/parent/students/new';
  static const String parentSubscriptions = '/parent/subscriptions';

  // Student.
  static const String student = '/student';
  static const String studentLocked = '/student/locked';
  static const String studentVideo = '/student/courses/:courseId/videos/:videoId';
  static String studentVideoFor(String courseId, String videoId) =>
      '/student/courses/$courseId/videos/$videoId';

  // Teacher.
  static const String teacher = '/teacher';
  static const String teacherCourseAnalytics =
      '/teacher/courses/:courseId/analytics';
  static String teacherCourseAnalyticsFor(String courseId) =>
      '/teacher/courses/$courseId/analytics';

  /// Home route for a signed-in user of [role].
  static String homeFor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return student;
      case UserRole.parent:
        return parent;
      case UserRole.teacher:
        return teacher;
      case UserRole.admin:
        return admin;
    }
  }
}
