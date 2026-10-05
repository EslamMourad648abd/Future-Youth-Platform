import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../modules/operations/screens/client/client_activity.dart';
import '../modules/operations/screens/client/client_overview.dart';
import '../modules/operations/screens/main_dashboard/reports.dart';
import '../modules/operations/screens/main_dashboard/tasks.dart';
import '../modules/training/screens/training_certificates.dart';
import '../modules/training/screens/training_courses_screen.dart';
import '../services/auth_service.dart';

// ============================================================
// PLATFORM
// ============================================================

import '../platform/dashboard.dart';

// ============================================================
// LOGIN
// ============================================================

import '../modules/login/login.dart';

// ============================================================
// BBC API
// ============================================================

import '../modules/bbc_api_tool/bbc_api.dart';

// ============================================================
// TRAINING
// ============================================================

import '../modules/training/screens/training_shell.dart';
import '../modules/training/screens/training_dashboard.dart';
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
// OPERATIONS / ONBOARDING
// ============================================================

import '../modules/operations/screens/client/client_channels.dart';
import '../modules/operations/screens/client/client_activation.dart';

import '../modules/operations/screens/main_dashboard/shell.dart';
import '../modules/operations/screens/main_dashboard/dashboard.dart';
import '../modules/operations/screens/main_dashboard/clients.dart';

// ============================================================
// CLIENT WORKSPACE
// ============================================================

import '../modules/operations/screens/client/client_workspace.dart';
import '../modules/operations/screens/client/client_verification.dart';
import '../modules/operations/screens/client/client_chatbot.dart';
import '../modules/operations/screens/client/client_group.dart';
import '../services/platform_config.dart';
// ============================================================
// APP ROUTER
// ============================================================

class AppRouter {
  // ============================================================
  // OPERATIONS / ONBOARDING
  // ============================================================

  static const operations =
      '/operations';

  static const onboarding =
      '/operations/onboarding';

  static const onboardingClients =
      '/operations/onboarding/clients';

  static const onboardingTasks =
      '/operations/onboarding/tasks';

  static const onboardingReports =
      '/operations/onboarding/reports';

  // ============================================================
  // CLIENT WORKSPACE
  // ============================================================

  static const onboardingClient =
      '/operations/onboarding/client/:clientId';

  static const clientOverview =
      '/operations/onboarding/client/:clientId/overview';

  static const clientActivation =
      '/operations/onboarding/client/:clientId/activation';

  static const clientChannels =
      '/operations/onboarding/client/:clientId/channels';

  static const clientVerification =
      '/operations/onboarding/client/:clientId/verification';

  static const clientChatbot =
      '/operations/onboarding/client/:clientId/chatbot';

  static const clientGroup =
      '/operations/onboarding/client/:clientId/group';

  static const clientActivity =
      '/operations/onboarding/client/:clientId/activity';

  // ============================================================
  // CLIENT URL HELPERS
  // ============================================================

  static String onboardingClientPath(
      String clientId,
      ) {
    return '/operations/onboarding/client/'
        '${Uri.encodeComponent(clientId)}';
  }

  static String clientOverviewPath(
      String clientId,
      ) {
    return '${onboardingClientPath(clientId)}/overview';
  }

  static String clientActivationPath(
      String clientId,
      ) {
    return '${onboardingClientPath(clientId)}/activation';
  }

  static String clientChannelsPath(
      String clientId,
      ) {
    return '${onboardingClientPath(clientId)}/channels';
  }

  static String clientVerificationPath(
      String clientId,
      ) {
    return '${onboardingClientPath(clientId)}/verification';
  }

  static String clientChatbotPath(
      String clientId,
      ) {
    return '${onboardingClientPath(clientId)}/chatbot';
  }

  static String clientGroupPath(
      String clientId,
      ) {
    return '${onboardingClientPath(clientId)}/group';
  }

  static String clientActivityPath(
      String clientId,
      ) {
    return '${onboardingClientPath(clientId)}/activity';
  }

  // ============================================================
  // MAIN ROUTES
  // ============================================================

  static const login =
      '/login';

  static const home =
      '/home';

  static const bbcApi =
      '/bbc-api';

  // ============================================================
  // TRAINING ROOT
  // ============================================================

  static const training =
      '/training';

  // ============================================================
  // TRAINING SECTIONS
  // ============================================================

  static const trainingCourses =
      '/training/courses';

  static const trainingProgress =
      '/training/progress';

  static const trainingCertificates =
      '/training/certificates';

  // ============================================================
  // TRAINING COURSE ROUTES
  // ============================================================

  static const course =
      '/training/course/:courseId';

  static const lesson =
      '/training/course/:courseId/lesson/:lessonId';

  static const quiz =
      '/training/course/:courseId/lesson/:lessonId/quiz';

  static const quizReview =
      '/training/course/:courseId/lesson/:lessonId/quiz/review';

  // ============================================================
  // TRAINING URL HELPERS
  // ============================================================

  static String coursePath(
      String courseId,
      ) {
    return '/training/course/'
        '${Uri.encodeComponent(courseId)}';
  }

  static String lessonPath(
      String courseId,
      String lessonId,
      ) {
    return '${coursePath(courseId)}/lesson/'
        '${Uri.encodeComponent(lessonId)}';
  }

  static String quizPath(
      String courseId,
      String lessonId,
      ) {
    return '${lessonPath(courseId, lessonId)}/quiz';
  }

  static String quizReviewPath(
      String courseId,
      String lessonId,
      ) {
    return '${quizPath(courseId, lessonId)}/review';
  }

  // ============================================================
  // ADMIN CONSOLE ROUTES
  // ============================================================

  static const adminConsole =
      '/admin-console';

  static const adminUsers =
      '/admin-console/users';

  static const adminTrainingManagement =
      '/admin-console/training-management';

  static const adminAnalytics =
      '/admin-console/analytics';

  static const adminMetaWhatsApp =
      '/admin-console/meta-whatsapp';

  static const adminLogs =
      '/admin-console/logs';

  // ============================================================
  // ROUTER
  // ============================================================

  static final GoRouter router =
  GoRouter(
    initialLocation:
    login,

    debugLogDiagnostics:
    true,

    // ==========================================================
    // AUTH GUARD
    // ==========================================================

    redirect: (
        context,
        state,
        ) async {
      final user =
          FirebaseAuth.instance.currentUser;

      final location =
          state.uri.path;

      final isLogin =
          location == login;

      // --------------------------------------------------------
      // NOT LOGGED IN
      // --------------------------------------------------------

      if (user == null) {
        if (isLogin) {
          return null;
        }

        return login;
      }

      // --------------------------------------------------------
      // LOAD LATEST ROLE
      // --------------------------------------------------------

      try {
        await AuthService.loadUserRole();
      } catch (e) {
        debugPrint(
          'Router role loading failed: $e',
        );
      }

      // --------------------------------------------------------
      // ALREADY LOGGED IN -> LOGIN
      // --------------------------------------------------------

      if (isLogin) {
        return home;
      }

      // --------------------------------------------------------
      // PLATFORM ISOLATION
      // --------------------------------------------------------
      
      final config = PlatformConfig.current;
      if (config.isStandalone) {
        // Block Admin Console for standalone platforms
        if (location.startsWith(adminConsole)) return home;
        
        // Block other platforms
        switch (config.type) {
          case PlatformType.support:
          case PlatformType.onboarding:
            if (!location.startsWith(operations) && !location.startsWith(home)) return home;
            break;
          case PlatformType.trainee:
            if (!location.startsWith(training) && !location.startsWith(home)) return home;
            break;
          case PlatformType.apiTool:
            if (!location.startsWith(bbcApi) && !location.startsWith(home)) return home;
            break;
          default: break;
        }
      }

      // --------------------------------------------------------
      // SUPER ADMIN CONSOLE
      // --------------------------------------------------------

      if (location == adminConsole ||
          location == adminUsers ||
          location == adminTrainingManagement ||
          location == adminAnalytics ||
          location == adminMetaWhatsApp ||
          location == adminLogs) {
        if (AuthService.isSuperAdmin) {
          return null;
        }

        return home;
      }

      // --------------------------------------------------------
      // BBC API
      // --------------------------------------------------------

      if (location == bbcApi ||
          location.startsWith('$bbcApi/')) {
        if (AuthService.isSuperAdmin ||
            AuthService.isAgent ||
            AuthService.isTrainee) {
          return null;
        }

        return home;
      }

      // --------------------------------------------------------
      // TRAINING
      // --------------------------------------------------------

      if (location == training ||
          location.startsWith('$training/')) {
        if (AuthService.isSuperAdmin ||
            AuthService.isTrainee) {
          return null;
        }

        return home;
      }

      // --------------------------------------------------------
      // OPERATIONS / ONBOARDING
      // --------------------------------------------------------

      if (location == operations ||
          location.startsWith('$operations/')) {
        if (AuthService.isSuperAdmin ||
            AuthService.isAgent ||
            AuthService.isSupportAgent) {
          return null;
        }

        return home;
      }

      // --------------------------------------------------------
      // DEFAULT
      // --------------------------------------------------------

      return null;
    },

    // ==========================================================
    // ROUTES
    // ==========================================================

    routes: [
      // ========================================================
      // LOGIN
      // ========================================================

      GoRoute(
        path:
        login,

        name:
        'login',

        builder: (
            context,
            state,
            ) {
          return const LoginPage();
        },
      ),

      // ========================================================
      // PLATFORM DASHBOARD
      // ========================================================

      GoRoute(
        path:
        home,

        name:
        'home',

        builder: (
            context,
            state,
            ) {
          return const PlatformDashboard();
        },
      ),

      // ========================================================
      // BBC API
      // ========================================================

      GoRoute(
        path:
        bbcApi,

        name:
        'bbc-api',

        builder: (
            context,
            state,
            ) {
          return const BbcApiHomeScreen();
        },
      ),

      // ========================================================
      // TRAINING SHELL
      // ========================================================

      ShellRoute(
        builder: (
            context,
            state,
            child,
            ) {
          return TrainingShell(
            child:
            child,
          );
        },

        routes: [
          // ====================================================
          // TRAINING DASHBOARD
          // ====================================================

          GoRoute(
            path:
            training,

            name:
            'training',

            builder: (
                context,
                state,
                ) {
              return const TrainingDashboard();
            },
          ),

          // ====================================================
          // COURSES
          // ====================================================

          GoRoute(
            path:
            trainingCourses,

            name:
            'training-courses',

            builder: (
                context,
                state,
                ) {
              return const TrainingCoursesScreen();
            },
          ),

          // ====================================================
          // MY PROGRESS
          // ====================================================

          GoRoute(
            path:
            trainingProgress,

            name:
            'training-progress',

            builder: (
                context,
                state,
                ) {
              return const TrainingDashboard();
            },
          ),

          // ====================================================
          // CERTIFICATES
          // ====================================================

          GoRoute(
            path:
            trainingCertificates,

            name:
            'training-certificates',

            builder: (
                context,
                state,
                ) {
              return const TrainingCertificates();
            },
          ),

          // ====================================================
          // TRAINING COURSE
          // ====================================================

          GoRoute(
            path:
            course,

            name:
            'training-course',

            builder: (
                context,
                state,
                ) {
              final courseId =
              state.pathParameters[
              'courseId'];

              if (courseId == null ||
                  courseId.isEmpty) {
                return const _RouteErrorPage(
                  message:
                  'Course ID is missing.',
                );
              }

              return _CourseRouteLoader(
                courseId:
                courseId,
              );
            },
          ),

          // ====================================================
          // TRAINING LESSON
          // ====================================================

          GoRoute(
            path:
            lesson,

            name:
            'training-lesson',

            builder: (
                context,
                state,
                ) {
              final courseId =
              state.pathParameters[
              'courseId'];

              final lessonId =
              state.pathParameters[
              'lessonId'];

              if (courseId == null ||
                  courseId.isEmpty ||
                  lessonId == null ||
                  lessonId.isEmpty) {
                return const _RouteErrorPage(
                  message:
                  'Course or lesson ID is missing.',
                );
              }

              return _LessonRouteLoader(
                courseId:
                courseId,

                lessonId:
                lessonId,
              );
            },
          ),

          // ====================================================
          // TRAINING QUIZ
          // ====================================================

          GoRoute(
            path:
            quiz,

            name:
            'training-quiz',

            builder: (
                context,
                state,
                ) {
              final courseId =
              state.pathParameters[
              'courseId'];

              final lessonId =
              state.pathParameters[
              'lessonId'];

              if (courseId == null ||
                  courseId.isEmpty ||
                  lessonId == null ||
                  lessonId.isEmpty) {
                return const _RouteErrorPage(
                  message:
                  'Course or lesson ID is missing.',
                );
              }

              return QuizScreen(
                courseId:
                courseId,

                lessonId:
                lessonId,
              );
            },
          ),

          // ====================================================
          // TRAINING QUIZ REVIEW
          // ====================================================

          GoRoute(
            path:
            quizReview,

            name:
            'training-quiz-review',

            builder: (
                context,
                state,
                ) {
              final courseId =
              state.pathParameters[
              'courseId'];

              final lessonId =
              state.pathParameters[
              'lessonId'];

              if (courseId == null ||
                  courseId.isEmpty ||
                  lessonId == null ||
                  lessonId.isEmpty) {
                return const _RouteErrorPage(
                  message:
                  'Course or lesson ID is missing.',
                );
              }

              return QuizReviewScreen(
                courseId:
                courseId,

                lessonId:
                lessonId,
              );
            },
          ),
        ],
      ),

      // ========================================================
      // SUPER ADMIN CONSOLE
      // ========================================================

      GoRoute(
        path:
        adminConsole,

        name:
        'admin-console',

        redirect: (
            context,
            state,
            ) {
          return adminUsers;
        },

        builder: (
            context,
            state,
            ) {
          return const PlatformAdminConsole();
        },
      ),

      // ========================================================
      // ADMIN USERS
      // ========================================================

      GoRoute(
        path:
        adminUsers,

        name:
        'admin-users',

        builder: (
            context,
            state,
            ) {
          return const PlatformAdminConsole();
        },
      ),

      // ========================================================
      // ADMIN TRAINING MANAGEMENT
      // ========================================================

      GoRoute(
        path:
        adminTrainingManagement,

        name:
        'admin-training-management',

        builder: (
            context,
            state,
            ) {
          return const PlatformAdminConsole();
        },
      ),

      // ========================================================
      // ADMIN ANALYTICS
      // ========================================================

      GoRoute(
        path:
        adminAnalytics,

        name:
        'admin-analytics',

        builder: (
            context,
            state,
            ) {
          return const PlatformAdminConsole();
        },
      ),

      // ========================================================
      // ADMIN META WHATSAPP
      // ========================================================

      GoRoute(
        path:
        adminMetaWhatsApp,

        name:
        'admin-meta-whatsapp',

        builder: (
            context,
            state,
            ) {
          return const PlatformAdminConsole();
        },
      ),

      GoRoute(
        path:
        adminLogs,

        name:
        'admin-logs',

        builder: (
            context,
            state,
            ) {
          return const PlatformAdminConsole();
        },
      ),


      // ========================================================
      // ONBOARDING SHELL
      // ========================================================

      ShellRoute(
        builder: (
            context,
            state,
            child,
            ) {
          return OnboardingShell(
            child:
            child,
          );
        },

        routes: [
          // ====================================================
          // OPERATIONS ROOT
          // ====================================================

          GoRoute(
            path:
            operations,

            name:
            'operations',

            redirect: (
                context,
                state,
                ) {
              return onboarding;
            },
          ),

          // ====================================================
          // ONBOARDING DASHBOARD
          // ====================================================

          GoRoute(
            path:
            onboarding,

            name:
            'onboarding',

            builder: (
                context,
                state,
                ) {
              return const OnboardingDashboard();
            },
          ),

          // ====================================================
          // CLIENTS
          // ====================================================

          GoRoute(
            path:
            onboardingClients,

            name:
            'onboarding-clients',

            builder: (
                context,
                state,
                ) {
              return const OnboardingClientsScreen();
            },
          ),

          // ====================================================
          // TASKS
          //
          // IMPORTANT:
          //
          // Tasks remain user-level and are NOT part of the
          // individual client workspace.
          //
          // ====================================================

          GoRoute(
            path:
            onboardingTasks,

            name:
            'onboarding-tasks',

            builder: (
                context,
                state,
                ) {
              return const OnboardingTasks();
            },
          ),

          // ====================================================
          // REPORTS
          // ====================================================

          GoRoute(
            path:
            onboardingReports,

            name:
            'onboarding-reports',

            builder: (
                context,
                state,
                ) {
              return const OnboardingReports();
            },
          ),
        ],
      ),

      // ========================================================
      // CLIENT WORKSPACE
      // ========================================================

      ShellRoute(
        builder: (
            context,
            state,
            child,
            ) {
          final clientId =
          state.pathParameters[
          'clientId'];

          if (clientId == null ||
              clientId.isEmpty) {
            return const _RouteErrorPage(
              message:
              'Client ID is missing.',
            );
          }

          return ClientWorkspace(
            clientId:
            clientId,

            child:
            child,
          );
        },

        routes: [
          // ====================================================
          // CLIENT ROOT
          // ====================================================

          GoRoute(
            path:
            onboardingClient,

            name:
            'onboarding-client',

            redirect: (
                context,
                state,
                ) {
              final clientId =
              state.pathParameters[
              'clientId'];

              if (clientId == null ||
                  clientId.isEmpty) {
                return home;
              }

              return clientOverviewPath(
                clientId,
              );
            },

            builder: (
                context,
                state,
                ) {
              return const SizedBox.shrink();
            },
          ),

          // ====================================================
          // OVERVIEW
          // ====================================================

          GoRoute(
            path:
            clientOverview,

            name:
            'client-overview',

            builder: (
                context,
                state,
                ) {
              final clientId =
              state.pathParameters[
              'clientId'];

              if (clientId == null ||
                  clientId.isEmpty) {
                return const _RouteErrorPage(
                  message:
                  'Client ID is missing.',
                );
              }

              return ClientOverviewScreen(
                clientId:
                clientId,
              );
            },
          ),

          // ====================================================
          // ACTIVATION
          // ====================================================

          GoRoute(
            path:
            clientActivation,

            name:
            'client-activation',

            builder: (
                context,
                state,
                ) {
              final clientId =
              state.pathParameters[
              'clientId'];

              if (clientId == null ||
                  clientId.isEmpty) {
                return const _RouteErrorPage(
                  message:
                  'Client ID is missing.',
                );
              }

              return ClientActivationScreen(
                clientId:
                clientId,
              );
            },
          ),

          // ====================================================
          // CHANNELS
          // ====================================================

          GoRoute(
            path:
            clientChannels,

            name:
            'client-channels',

            builder: (
                context,
                state,
                ) {
              final clientId =
              state.pathParameters[
              'clientId'];

              if (clientId == null ||
                  clientId.isEmpty) {
                return const _RouteErrorPage(
                  message:
                  'Client ID is missing.',
                );
              }

              return ClientChannelsScreen(
                clientId:
                clientId,
              );
            },
          ),

          // ====================================================
// VERIFICATION
// ====================================================

          GoRoute(
            path:
            clientVerification,

            name:
            'client-verification',

            builder: (
                context,
                state,
                ) {
              final clientId =
              state.pathParameters[
              'clientId'];

              if (clientId == null ||
                  clientId.isEmpty) {
                return const _RouteErrorPage(
                  message:
                  'Client ID is missing.',
                );
              }

              return ClientVerificationScreen(
                clientId:
                clientId,
              );
            },
          ),

          GoRoute(
            path: clientChatbot,
            name: 'client-chatbot',
            builder: (
                context,
                state,
                ) {
              final clientId =
              state.pathParameters['clientId'];

              if (clientId == null ||
                  clientId.isEmpty) {
                return const Scaffold(
                  body: Center(
                    child: Text(
                      'Client ID is missing.',
                    ),
                  ),
                );
              }

              return ClientChatbotScreen(
                clientId: clientId,
              );
            },
          ),

          GoRoute(
            path: clientGroup,
            name: 'client-group',
            builder: (
                context,
                state,
                ) {
              final clientId = state.pathParameters['clientId'];

              if (clientId == null || clientId.isEmpty) {
                return const Scaffold(
                  body: Center(
                    child: Text('Client ID is missing.'),
                  ),
                );
              }

              return ClientGroupScreen(
                clientId: clientId,
              );
            },
          ),

          GoRoute(
            path: AppRouter.clientActivity,
            name: 'client-activity',
            builder: (
                context,
                state,
                ) {
              final clientId =
              state.pathParameters['clientId'];

              if (clientId == null ||
                  clientId.trim().isEmpty) {
                return const Scaffold(
                  body: Center(
                    child: Text(
                      'Client ID is missing.',
                    ),
                  ),
                );
              }

              return ClientActivityScreen(
                clientId: clientId,
              );
            },
          ),
        ],
      ),
    ],

    // ==========================================================
    // ERROR
    // ==========================================================

    errorBuilder: (
        context,
        state,
        ) {
      return Scaffold(
        backgroundColor:
        const Color(0xffF5F8FC),

        body:
        Center(
          child:
          Padding(
            padding:
            const EdgeInsets.all(24),

            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,

              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),

                const SizedBox(
                  height: 16,
                ),

                const Text(
                  'Page not found',

                  style:
                  TextStyle(
                    fontSize: 24,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  state.uri.toString(),

                  textAlign:
                  TextAlign.center,

                  style:
                  const TextStyle(
                    color:
                    Colors.grey,
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                ElevatedButton(
                  onPressed: () {
                    context.go(
                      home,
                    );
                  },

                  child:
                  const Text(
                    'Go to Dashboard',
                  ),
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

class _CourseRouteLoader
    extends StatefulWidget {
  final String courseId;

  const _CourseRouteLoader({
    required this.courseId,
  });

  @override
  State<_CourseRouteLoader>
  createState() =>
      _CourseRouteLoaderState();
}

class _CourseRouteLoaderState
    extends State<_CourseRouteLoader> {
  final FirebaseTrainingRepository
  _repository =
  FirebaseTrainingRepository();

  CourseModel? _course;

  bool _loading =
  true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadCourse();
  }

  Future<void> _loadCourse() async {
    try {
      final courses =
      await _repository.getCourses();

      CourseModel? found;

      for (final course in courses) {
        if (course.id ==
            widget.courseId) {
          found =
              course;
          break;
        }
      }

      if (!mounted) {
        return;
      }

      if (found == null) {
        setState(() {
          _loading =
          false;

          _error =
          'Course not found.';
        });

        return;
      }

      setState(() {
        _course =
            found;

        _loading =
        false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
        false;

        _error =
        'Failed to load course: $e';
      });
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_loading) {
      return const _RouteLoadingPage();
    }

    if (_error != null ||
        _course == null) {
      return _RouteErrorPage(
        message:
        _error ??
            'Course not found.',
      );
    }

    return CourseDetails(
      course:
      _course!,
    );
  }
}

// ============================================================
// LESSON ROUTE LOADER
// ============================================================

class _LessonRouteLoader
    extends StatefulWidget {
  final String courseId;

  final String lessonId;

  const _LessonRouteLoader({
    required this.courseId,
    required this.lessonId,
  });

  @override
  State<_LessonRouteLoader>
  createState() =>
      _LessonRouteLoaderState();
}

class _LessonRouteLoaderState
    extends State<_LessonRouteLoader> {
  final FirebaseTrainingRepository
  _repository =
  FirebaseTrainingRepository();

  LessonModel? _lesson;

  bool _loading =
  true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadLesson();
  }

  Future<void> _loadLesson() async {
    try {
      final lessons =
      await _repository.getLessons(
        widget.courseId,
      );

      LessonModel? found;

      for (final lesson in lessons) {
        if (lesson.id ==
            widget.lessonId) {
          found =
              lesson;
          break;
        }
      }

      if (!mounted) {
        return;
      }

      if (found == null) {
        setState(() {
          _loading =
          false;

          _error =
          'Lesson not found.';
        });

        return;
      }

      setState(() {
        _lesson =
            found;

        _loading =
        false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
        false;

        _error =
        'Failed to load lesson: $e';
      });
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_loading) {
      return const _RouteLoadingPage();
    }

    if (_error != null ||
        _lesson == null) {
      return _RouteErrorPage(
        message:
        _error ??
            'Lesson not found.',
      );
    }

    return LessonScreen(
      lesson:
      _lesson!,
    );
  }
}

// ============================================================
// CLIENT PLACEHOLDERS
// ============================================================

/*
class _ClientOverviewPlaceholder
    extends StatelessWidget {
  const _ClientOverviewPlaceholder();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const _ClientPlaceholderContent(
      icon:
      Icons.dashboard_outlined,
      title:
      'Client Overview',
      description:
      'Client overview information will appear here.',
    );
  }
}

class _ClientTasksPlaceholder
    extends StatelessWidget {
  const _ClientTasksPlaceholder();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const _ClientPlaceholderContent(
      icon:
      Icons.task_alt_outlined,
      title:
      'Client Tasks',
      description:
      'Client-specific onboarding tasks will appear here.',
    );
  }
}

class _ClientChannelsPlaceholder
    extends StatelessWidget {
  const _ClientChannelsPlaceholder();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const _ClientPlaceholderContent(
      icon:
      Icons.hub_outlined,
      title:
      'Channels',
      description:
      'Client communication channels will appear here.',
    );
  }
}

class _ClientVerificationPlaceholder
    extends StatelessWidget {
  const _ClientVerificationPlaceholder();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const _ClientPlaceholderContent(
      icon:
      Icons.verified_user_outlined,
      title:
      'Verification',
      description:
      'Client verification information will appear here.',
    );
  }
}

class _ClientChatbotPlaceholder
    extends StatelessWidget {
  const _ClientChatbotPlaceholder();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const _ClientPlaceholderContent(
      icon:
      Icons.smart_toy_outlined,
      title:
      'Chatbot',
      description:
      'Client chatbot configuration will appear here.',
    );
  }
}

class _ClientGroupPlaceholder
    extends StatelessWidget {
  const _ClientGroupPlaceholder();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const _ClientPlaceholderContent(
      icon:
      Icons.groups_outlined,
      title:
      'Group',
      description:
      'Client group configuration will appear here.',
    );
  }
}

class _ClientActivityPlaceholder
    extends StatelessWidget {
  const _ClientActivityPlaceholder();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const _ClientPlaceholderContent(
      icon:
      Icons.history_outlined,
      title:
      'Activity',
      description:
      'Client activity and audit history will appear here.',
    );
  }
}
*/

/*
class _ClientPlaceholderContent
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String description;

  const _ClientPlaceholderContent({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(32),

        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            Icon(
              icon,
              size: 56,
              color:
              const Color(0xff003366),
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              title,

              style:
              const TextStyle(
                fontSize: 22,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              description,

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/

// ============================================================
// LOADING PAGE
// ============================================================

class _RouteLoadingPage
    extends StatelessWidget {
  const _RouteLoadingPage();

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor:
      theme.colorScheme.surface,

      body:
      Center(
        child:
        CircularProgressIndicator(
          color:
          theme.colorScheme.primary,
        ),
      ),
    );
  }
}

// ============================================================
// ROUTE ERROR PAGE
// ============================================================

class _RouteErrorPage
    extends StatelessWidget {
  final String message;

  const _RouteErrorPage({
    required this.message,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor:
      theme.colorScheme.surface,

      body:
      Center(
        child:
        Padding(
          padding:
          const EdgeInsets.all(24),

          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),

              const SizedBox(
                height: 16,
              ),

              Text(
                message,

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              ElevatedButton(
                onPressed: () {
                  context.go(
                    AppRouter.training,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child:
                const Text(
                  'Back to Training',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
