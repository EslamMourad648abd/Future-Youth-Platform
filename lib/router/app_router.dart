import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

// ============================================================
// LOGIN
// ============================================================

import '../modules/login/login.dart';

// ============================================================
// TRAINING
// ============================================================

import '../modules/training/screens/training_shell.dart';
import '../modules/training/screens/training_dashboard.dart';
import '../modules/training/screens/training_courses_screen.dart';
import '../modules/training/screens/training_certificates.dart';
import '../modules/training/screens/course_details.dart';
import '../modules/training/screens/lesson_screen.dart';
import '../modules/training/screens/quiz_screen.dart';
import '../modules/training/screens/quiz_review_screen.dart';

import '../modules/training/models/course_model.dart';
import '../modules/training/models/lesson_model.dart';

import '../modules/training/repositories/firebase_training_repository.dart';

// ============================================================
// SUPER ADMIN
// ============================================================

import '../admin_console/screens/super_admin_console.dart';

// ============================================================
// APP ROUTER
// ============================================================

class AppRouter {
  // ============================================================
  // MAIN ROUTES
  // ============================================================

  static const login = '/login';
  static const home = '/training';

  // ============================================================
  // TRAINING ROOT
  // ============================================================

  static const training = '/training';

  // ============================================================
  // TRAINING SECTIONS
  // ============================================================

  static const trainingCourses = '/training/courses';
  static const trainingProgress = '/training/progress';
  static const trainingCertificates = '/training/certificates';

  // ============================================================
  // TRAINING COURSE ROUTES
  // ============================================================

  static const course = '/training/course/:courseId';
  static const lesson = '/training/course/:courseId/lesson/:lessonId';
  static const quiz = '/training/course/:courseId/lesson/:lessonId/quiz';
  static const quizReview = '/training/course/:courseId/lesson/:lessonId/quiz/review';

  // ============================================================
  // TRAINING URL HELPERS
  // ============================================================

  static String coursePath(String courseId) {
    return '/training/course/${Uri.encodeComponent(courseId)}';
  }

  static String lessonPath(String courseId, String lessonId) {
    return '${coursePath(courseId)}/lesson/${Uri.encodeComponent(lessonId)}';
  }

  static String quizPath(String courseId, String lessonId) {
    return '${lessonPath(courseId, lessonId)}/quiz';
  }

  static String quizReviewPath(String courseId, String lessonId) {
    return '${quizPath(courseId, lessonId)}/review';
  }

  // ============================================================
  // ADMIN CONSOLE ROUTES
  // ============================================================

  static const adminConsole = '/admin-console';
  static const adminUsers = '/admin-console/users';
  static const adminTrainingManagement = '/admin-console/training-management';
  static const adminAnalytics = '/admin-console/analytics';
  static const adminLogs = '/admin-console/logs';

  // ============================================================
  // ROUTER DEFINITION
  // ============================================================

  static final GoRouter router = GoRouter(
    initialLocation: login,
    debugLogDiagnostics: true,

    // ==========================================================
    // AUTH GUARD
    // ==========================================================

    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final location = state.uri.path;
      final isLogin = location == login;

      // --------------------------------------------------------
      // NOT LOGGED IN
      // --------------------------------------------------------

      if (user == null) {
        if (isLogin) return null;
        return login;
      }

      // --------------------------------------------------------
      // LOAD LATEST ROLE
      // --------------------------------------------------------

      try {
        await AuthService.loadUserRole();
      } catch (e) {
        debugPrint('Router role loading failed: $e');
      }

      // --------------------------------------------------------
      // ALREADY LOGGED IN -> ATTEMPTING LOGIN PAGE OR ROOT/HOME
      // --------------------------------------------------------

      if (isLogin || location == '/' || location == '/home') {
        return training;
      }

      // --------------------------------------------------------
      // SUPER ADMIN CONSOLE ACCESS CONTROL
      // --------------------------------------------------------

      if (location.startsWith(adminConsole)) {
        if (AuthService.isSuperAdmin) {
          return null;
        }
        return training;
      }

      // --------------------------------------------------------
      // TRAINING PORTAL
      // --------------------------------------------------------

      if (location.startsWith(training)) {
        return null;
      }

      // --------------------------------------------------------
      // FALLBACK TO TRAINING
      // --------------------------------------------------------

      return training;
    },

    // ==========================================================
    // ROUTES
    // ==========================================================

    routes: [
      // ========================================================
      // LOGIN
      // ========================================================

      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // ========================================================
      // TRAINING SHELL & SUB-ROUTES
      // ========================================================

      ShellRoute(
        builder: (context, state, child) {
          return TrainingShell(child: child);
        },
        routes: [
          GoRoute(
            path: training,
            name: 'training',
            builder: (context, state) => const TrainingDashboard(),
          ),
          GoRoute(
            path: trainingCourses,
            name: 'training-courses',
            builder: (context, state) => const TrainingCoursesScreen(),
          ),
          GoRoute(
            path: trainingProgress,
            name: 'training-progress',
            builder: (context, state) => const TrainingDashboard(),
          ),
          GoRoute(
            path: trainingCertificates,
            name: 'training-certificates',
            builder: (context, state) => const TrainingCertificates(),
          ),
          GoRoute(
            path: course,
            name: 'training-course',
            builder: (context, state) {
              final courseId = state.pathParameters['courseId'];
              if (courseId == null || courseId.isEmpty) {
                return const _RouteErrorPage(message: 'Course ID is missing.');
              }
              return _CourseRouteLoader(courseId: courseId);
            },
          ),
          GoRoute(
            path: lesson,
            name: 'training-lesson',
            builder: (context, state) {
              final courseId = state.pathParameters['courseId'];
              final lessonId = state.pathParameters['lessonId'];
              if (courseId == null || courseId.isEmpty || lessonId == null || lessonId.isEmpty) {
                return const _RouteErrorPage(message: 'Course or lesson ID is missing.');
              }
              return _LessonRouteLoader(courseId: courseId, lessonId: lessonId);
            },
          ),
          GoRoute(
            path: quiz,
            name: 'training-quiz',
            builder: (context, state) {
              final courseId = state.pathParameters['courseId'];
              final lessonId = state.pathParameters['lessonId'];
              if (courseId == null || courseId.isEmpty || lessonId == null || lessonId.isEmpty) {
                return const _RouteErrorPage(message: 'Course or lesson ID is missing.');
              }
              return QuizScreen(courseId: courseId, lessonId: lessonId);
            },
          ),
          GoRoute(
            path: quizReview,
            name: 'training-quiz-review',
            builder: (context, state) {
              final courseId = state.pathParameters['courseId'];
              final lessonId = state.pathParameters['lessonId'];
              if (courseId == null || courseId.isEmpty || lessonId == null || lessonId.isEmpty) {
                return const _RouteErrorPage(message: 'Course or lesson ID is missing.');
              }
              return QuizReviewScreen(courseId: courseId, lessonId: lessonId);
            },
          ),
        ],
      ),

      // ========================================================
      // SUPER ADMIN CONSOLE
      // ========================================================

      GoRoute(
        path: adminConsole,
        name: 'admin-console',
        redirect: (context, state) => adminUsers,
        builder: (context, state) => const PlatformAdminConsole(),
      ),
      GoRoute(
        path: adminUsers,
        name: 'admin-users',
        builder: (context, state) => const PlatformAdminConsole(),
      ),
      GoRoute(
        path: adminTrainingManagement,
        name: 'admin-training-management',
        builder: (context, state) => const PlatformAdminConsole(),
      ),
      GoRoute(
        path: adminAnalytics,
        name: 'admin-analytics',
        builder: (context, state) => const PlatformAdminConsole(),
      ),
      GoRoute(
        path: adminLogs,
        name: 'admin-logs',
        builder: (context, state) => const PlatformAdminConsole(),
      ),
    ],

    // ==========================================================
    // ERROR PAGE
    // ==========================================================

    errorBuilder: (context, state) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Page not found',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  state.uri.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(training),
                  child: const Text('Go to Training Portal'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ============================================================
// COURSE ROUTE LOADER
// ============================================================

class _CourseRouteLoader extends StatefulWidget {
  final String courseId;

  const _CourseRouteLoader({required this.courseId});

  @override
  State<_CourseRouteLoader> createState() => _CourseRouteLoaderState();
}

class _CourseRouteLoaderState extends State<_CourseRouteLoader> {
  final FirebaseTrainingRepository _repository = FirebaseTrainingRepository();
  CourseModel? _course;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    try {
      final courses = await _repository.getCourses();
      CourseModel? found;
      for (final course in courses) {
        if (course.id == widget.courseId) {
          found = course;
          break;
        }
      }

      if (!mounted) return;

      if (found == null) {
        setState(() {
          _loading = false;
          _error = 'Course not found.';
        });
        return;
      }

      setState(() {
        _course = found;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load course: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _RouteLoadingPage();
    if (_error != null || _course == null) {
      return _RouteErrorPage(message: _error ?? 'Course not found.');
    }
    return CourseDetails(course: _course!);
  }
}

// ============================================================
// LESSON ROUTE LOADER
// ============================================================

class _LessonRouteLoader extends StatefulWidget {
  final String courseId;
  final String lessonId;

  const _LessonRouteLoader({required this.courseId, required this.lessonId});

  @override
  State<_LessonRouteLoader> createState() => _LessonRouteLoaderState();
}

class _LessonRouteLoaderState extends State<_LessonRouteLoader> {
  final FirebaseTrainingRepository _repository = FirebaseTrainingRepository();
  LessonModel? _lesson;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    try {
      final lessons = await _repository.getLessons(widget.courseId);
      LessonModel? found;
      for (final lesson in lessons) {
        if (lesson.id == widget.lessonId) {
          found = lesson;
          break;
        }
      }

      if (!mounted) return;

      if (found == null) {
        setState(() {
          _loading = false;
          _error = 'Lesson not found.';
        });
        return;
      }

      setState(() {
        _lesson = found;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load lesson: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _RouteLoadingPage();
    if (_error != null || _lesson == null) {
      return _RouteErrorPage(message: _error ?? 'Lesson not found.');
    }
    return LessonScreen(lesson: _lesson!);
  }
}

// ============================================================
// ROUTE LOADING PAGE
// ============================================================

class _RouteLoadingPage extends StatelessWidget {
  const _RouteLoadingPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
    );
  }
}

// ============================================================
// ROUTE ERROR PAGE
// ============================================================

class _RouteErrorPage extends StatelessWidget {
  final String message;

  const _RouteErrorPage({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRouter.training),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: const Text('Back to Training'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
