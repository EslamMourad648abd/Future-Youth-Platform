import 'package:go_router/go_router.dart';

import '../core/constants/user_role.dart';
import '../features/admin/presentation/admin_dashboard_page.dart';
import '../features/admin/presentation/create_admin_page.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/role_select_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/parent/presentation/create_student_page.dart';
import '../features/parent/presentation/parent_dashboard_page.dart';
import '../features/parent/presentation/subscription_page.dart';
import '../features/student/presentation/student_home_page.dart';
import '../features/student/presentation/course_details_page.dart';
import '../features/student/presentation/video_player_page.dart';
import '../features/teacher/presentation/teacher_dashboard_page.dart';
import '../features/teacher/presentation/course_analytics_page.dart';
import 'fyp_redirect.dart';
import 'fyp_routes.dart';

GoRouter createFypRouter(AuthController authController) {
  return GoRouter(
    initialLocation: FypRoutes.entry,
    refreshListenable: authController,
    redirect: (context, state) {
      return fypRedirect(
        location: state.uri.path,
        signedIn: authController.signedIn,
        role: authController.role,
      );
    },
    routes: [
      GoRoute(
        path: FypRoutes.entry,
        builder: (context, state) => const RoleSelectPage(),
      ),
      GoRoute(
        path: FypRoutes.login,
        builder: (context, state) {
          final roleStr = state.pathParameters['role'];
          final role = UserRole.tryParse(roleStr);
          if (role == null) return const RoleSelectPage();
          return LoginPage(role: role);
        },
      ),
      GoRoute(
        path: FypRoutes.signup,
        builder: (context, state) {
          final roleStr = state.pathParameters['role'];
          final role = UserRole.tryParse(roleStr);
          if (role == null || !role.canSelfSignUp) return const RoleSelectPage();
          return SignupPage(role: role);
        },
      ),
      GoRoute(
        path: FypRoutes.admin,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: FypRoutes.adminCreateAdmin,
        builder: (context, state) => const CreateAdminPage(),
      ),
      GoRoute(
        path: FypRoutes.parent,
        builder: (context, state) => const ParentDashboardPage(),
      ),
      GoRoute(
        path: FypRoutes.parentCreateStudent,
        builder: (context, state) => const CreateStudentPage(),
      ),
      GoRoute(
        path: FypRoutes.parentSubscriptions,
        builder: (context, state) => const SubscriptionPage(),
      ),
      GoRoute(
        path: FypRoutes.student,
        builder: (context, state) => const StudentHomePage(),
      ),
      GoRoute(
        path: FypRoutes.studentCourse,
        builder: (context, state) => StudentCourseDetailsPage(
          courseId: state.pathParameters['courseId'] ?? '',
        ),
      ),
      GoRoute(
        path: FypRoutes.studentVideo,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId'] ?? '';
          final videoId = state.pathParameters['videoId'] ?? '';
          return VideoPlayerPage(courseId: courseId, videoId: videoId);
        },
      ),
      GoRoute(
        path: FypRoutes.teacher,
        builder: (context, state) => const TeacherDashboardPage(),
      ),
      GoRoute(
        path: FypRoutes.teacherCourseAnalytics,
        builder: (context, state) => CourseAnalyticsPage(
          courseId: state.pathParameters['courseId'] ?? '',
        ),
      ),
    ],
  );
}
