import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../router/app_router.dart';
import '../../../../../services/auth_service.dart';
import '../../../../../services/localization_service.dart';
import '../../../../../services/theme_service.dart';
import '../../../../../services/platform_config.dart';

const Color kOnboardingBrandColor =
Color(0xff003366);

class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(
      BuildContext context,
      ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 1100;

      if (isMobile) {
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu, color: theme.colorScheme.primary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Text(
              AuthService.isSupportAgent
                  ? (l10n?.translate('support') ?? 'Support')
                  : AuthService.isSuperAdmin
                      ? (l10n?.translate('operations') ?? 'Operations')
                      : AuthService.isTrainee
                          ? (l10n?.translate('trainee') ?? 'Trainee')
                          : (l10n?.translate('onboarding') ?? 'Onboarding'),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            actions: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.themeNotifier,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return IconButton(
                    onPressed: ThemeService.toggleTheme,
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    color: theme.colorScheme.primary,
                  );
                },
              ),
            ],
            shape: Border(
              bottom: BorderSide(
                color: theme.dividerColor,
              ),
            ),
          ),
          drawer: const Drawer(
            width: _OnboardingNavigation.width,
            child: _OnboardingNavigation(isDrawer: true),
          ),
          body: child,
        );
      }

      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Row(
          children: [
            const _OnboardingNavigation(),
            Expanded(
              child: child,
            ),
          ],
        ),
      );
    });
  }
}

// ============================================================
// LEFT NAVIGATION
// ============================================================

class _OnboardingNavigation
    extends StatelessWidget {
  final bool isDrawer;
  const _OnboardingNavigation({this.isDrawer = false});

  static const double width = 260;

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final location =
        GoRouterState.of(context)
            .uri
            .path;
    final l10n = AppLocalizations.of(context);

    return Container(
      width:
      width,

      decoration: BoxDecoration(
        color:
        theme.colorScheme.surface,

        border: isDrawer ? null : Border(
          right: BorderSide(
            color:
            theme.dividerColor,
          ),
        ),
      ),

      child: SafeArea(
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,

          children: [
            // ==================================================
            // BACK TO PLATFORM
            // ==================================================

            if (!PlatformConfig.current.isStandalone)
              Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  4,
                ),

                child: Material(
                  color:
                  Colors.transparent,

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),

                  child: InkWell(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),

                    onTap: () {
                      context.go(
                        AppRouter.home,
                      );
                    },

                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal:
                        10,
                        vertical:
                        10,
                      ),

                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .arrow_back_rounded,

                            size:
                            19,

                            color:
                            theme.colorScheme.primary,
                          ),

                          const SizedBox(
                            width:
                            9,
                          ),

                          Expanded(
                            child: Text(
                              l10n?.translate('back_to_platforms') ?? 'Back to Platforms',

                              style:
                              TextStyle(
                                fontSize:
                                13,

                                fontWeight:
                                FontWeight.bold,

                                color:
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ==================================================
            // HEADER
            // ==================================================

            const _OnboardingHeader(),

            const SizedBox(
              height:
              12,
            ),

            // ==================================================
            // NAVIGATION
            // ==================================================

            Expanded(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  12,
                ),

                child: Column(
                  children: [
                    // ==================================================
                    // DASHBOARD
                    // ==================================================

                    _NavigationItem(
                      icon:
                      Icons
                          .dashboard_outlined,

                      selectedIcon:
                      Icons.dashboard,

                      title: AuthService.isSupportAgent 
                        ? (l10n?.translate('Support Dashboard') ?? 'Support Dashboard')
                        : (l10n?.translate('dashboard') ?? 'Dashboard'),

                      selected:
                      location ==
                          AppRouter
                              .onboarding,

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(
                          AppRouter
                              .onboarding,
                        );
                      },
                    ),

                    // ==================================================
                    // TASKS
                    // ==================================================

                    _NavigationItem(
                      icon:
                      Icons
                          .task_alt_outlined,

                      selectedIcon:
                      Icons.task_alt,

                      title:
                      l10n?.translate('tasks') ?? 'Tasks',

                      selected:
                      location ==
                          AppRouter
                              .onboardingTasks,

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(
                          AppRouter
                              .onboardingTasks,
                        );
                      },
                    ),

                    // ==================================================
                    // CLIENTS
                    // ==================================================

                    _NavigationItem(
                      icon:
                      Icons
                          .people_outline,

                      selectedIcon:
                      Icons.people,

                      title: AuthService.isSupportAgent 
                        ? (l10n?.translate('Support Clients') ?? 'Support Clients')
                        : (l10n?.translate('clients') ?? 'Clients'),

                      selected:
                      location ==
                          AppRouter
                              .onboardingClients,

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(
                          AppRouter
                              .onboardingClients,
                        );
                      },
                    ),

                    // ==================================================
                    // REPORTS
                    // ==================================================

                    if (AuthService.isSuperAdmin && !PlatformConfig.current.isStandalone)
                      _NavigationItem(
                        icon:
                        Icons
                            .analytics_outlined,

                        selectedIcon:
                        Icons.analytics,

                        title:
                        l10n?.translate('reports') ?? 'Reports',

                        selected:
                        location ==
                            AppRouter
                                .onboardingReports,

                        onTap: () {
                          if (isDrawer) Navigator.pop(context);
                          context.go(
                            AppRouter
                                .onboardingReports,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // FOOTER
            // ==================================================

            const _OnboardingNavigationFooter(),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _OnboardingHeader
    extends StatelessWidget {
  const _OnboardingHeader();

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        12,
      ),

      child: Row(
        children: [
          Container(
            width:
            42,

            height:
            42,

            decoration:
            BoxDecoration(
              color:
              theme.colorScheme.primary
                  .withValues(
                alpha: 0.1,
              ),

              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),

            child:
            Icon(
              Icons
                  .business_center_outlined,

              color:
              theme.colorScheme.primary,

              size:
              23,
            ),
          ),

          const SizedBox(
            width:
            12,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  AuthService.isSupportAgent
                      ? (l10n?.translate('support') ?? 'Support')
                      : AuthService.isSuperAdmin
                          ? (l10n?.translate('operations') ?? 'Operations')
                          : AuthService.isTrainee
                              ? (l10n?.translate('trainee') ?? 'Trainee')
                              : (l10n?.translate('onboarding') ?? 'Onboarding'),
                  style: TextStyle(
                    fontSize:
                    17,

                    fontWeight:
                    FontWeight.w700,

                    color:
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),

                const SizedBox(
                  height:
                  2,
                ),

                Text(
                  AuthService.isSupportAgent
                      ? (l10n?.translate('Support Platform') ?? 'Support Platform')
                      : AuthService.isSuperAdmin
                          ? (l10n?.translate('Operations Platform') ?? 'Operations Platform')
                          : (l10n?.translate('Onboarding Platform') ?? 'Onboarding Platform'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff7A8491),
                  ),
                ),
              ],
            ),
          ),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeNotifier,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                onPressed: ThemeService.toggleTheme,
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NAVIGATION ITEM
// ============================================================

class _NavigationItem
    extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;

  final String title;

  final bool selected;

  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom:
        4,
      ),

      child: Material(
        color:
        Colors.transparent,

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        child: InkWell(
          onTap:
          onTap,

          borderRadius:
          BorderRadius.circular(
            10,
          ),

          child:
          AnimatedContainer(
            duration:
            const Duration(
              milliseconds:
              180,
            ),

            curve:
            Curves.easeOut,

            padding:
            const EdgeInsets.symmetric(
              horizontal:
              14,

              vertical:
              12,
            ),

            decoration:
            BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary
                  .withValues(
                alpha: 0.1,
              )
                  : Colors.transparent,

              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),

            child: Row(
              children: [
                Icon(
                  selected
                      ? selectedIcon
                      : icon,

                  size:
                  21,

                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),

                const SizedBox(
                  width:
                  13,
                ),

                Expanded(
                  child:
                  Text(
                    title,

                    style:
                    TextStyle(
                      fontSize:
                      14,

                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.w500,

                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                if (selected)
                  Container(
                    width:
                    4,

                    height:
                    18,

                    decoration:
                    BoxDecoration(
                      color:
                      theme.colorScheme.primary,

                      borderRadius:
                      BorderRadius.circular(
                        4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FOOTER
// ============================================================

class _OnboardingNavigationFooter
    extends StatelessWidget {
  const _OnboardingNavigationFooter();

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    
    final footerLabel = AuthService.isSupportAgent 
      ? (l10n?.translate('support_operations') ?? 'Support Operations')
      : AuthService.isSuperAdmin
        ? (l10n?.translate('operations') ?? 'Operations')
        : (l10n?.translate('onboarding_operations') ?? 'Onboarding Operations');

    return Container(
      padding:
      const EdgeInsets.fromLTRB(20, 12, 20, 20),

      decoration:
      BoxDecoration(
        border: Border(
          top: BorderSide(
            color:
            theme.dividerColor,
          ),
        ),
      ),

      child:
      Row(
        children: [
          Icon(
            Icons
                .settings_suggest_outlined,

            size:
            18,

            color:
            theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),

          const SizedBox(
            width:
            8,
          ),

          Text(
            footerLabel,

            style:
            TextStyle(
              fontSize:
              11,

              color:
              theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
