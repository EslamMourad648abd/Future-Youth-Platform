import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../services/theme_service.dart';
import '../../../services/localization_service.dart';
import '../../../services/platform_config.dart';

// ============================================================
// TRAINING BRAND
// ============================================================

const Color kTrainingBrandColor =
Color(0xff003366);

const Color kTrainingAccentColor =
Color(0xff80CFFF);

const Color kTrainingBorderColor =
Color(0xffE5EAF0);

const Color kTrainingTextColor =
Color(0xff1A1F26);

const Color kTrainingSecondaryTextColor =
Color(0xff7A8491);

// ============================================================
// TRAINING SHELL
// ============================================================
//
// Persistent Training Portal layout.
//
// Navigation:
//
//   Dashboard
//   Courses
//   Certificates
//
// Dashboard contains the overall training overview and progress.
// Courses contains the actual course catalogue.
// Certificates contains earned certificates.
//
// ============================================================

class TrainingShell extends StatelessWidget {
  const TrainingShell({
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
              l10n?.translate('training_portal') ?? 'Learning',
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
            width: _TrainingNavigation.width,
            child: _TrainingNavigation(isDrawer: true),
          ),
          body: child,
        );
      }

      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Row(
          children: [
            const _TrainingNavigation(),
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

class _TrainingNavigation
    extends StatelessWidget {
  final bool isDrawer;
  const _TrainingNavigation({this.isDrawer = false});

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
          right:
          BorderSide(
            color:
            theme.dividerColor,
          ),
        ),
      ),

      child:
      SafeArea(
        child:
        Column(
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

                child:
                Material(
                  color:
                  Colors.transparent,

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),

                  child:
                  InkWell(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),

                    onTap: () {
                      context.go(
                        AppRouter.home,
                      );
                    },

                    child:
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal:
                        10,
                        vertical:
                        10,
                      ),

                      child:
                      Row(
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
                            child:
                            Text(
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

            const _TrainingHeader(),

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

                child:
                Column(
                  children: [
                    // ==========================================
                    // DASHBOARD
                    // ==========================================

                    _TrainingNavigationItem(
                      icon:
                      Icons
                          .dashboard_outlined,

                      selectedIcon:
                      Icons.dashboard,

                      title:
                      l10n?.translate('dashboard') ?? 'Dashboard',

                      selected:
                      location ==
                          AppRouter
                              .training,

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(
                          AppRouter.training,
                        );
                      },
                    ),

                    // ==========================================
                    // COURSES
                    // ==========================================

                    _TrainingNavigationItem(
                      icon:
                      Icons
                          .menu_book_outlined,

                      selectedIcon:
                      Icons.menu_book,

                      title:
                      l10n?.translate('courses') ?? 'Courses',

                      selected:
                      location ==
                          AppRouter
                              .trainingCourses,

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(
                          AppRouter
                              .trainingCourses,
                        );
                      },
                    ),

                    // ==========================================
                    // CERTIFICATES
                    // ==========================================

                    _TrainingNavigationItem(
                      icon:
                      Icons
                          .workspace_premium_outlined,

                      selectedIcon:
                      Icons
                          .workspace_premium,

                      title:
                      l10n?.translate('certificates') ?? 'Certificates',

                      selected:
                      location ==
                          AppRouter
                              .trainingCertificates,

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(
                          AppRouter
                              .trainingCertificates,
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

            const _TrainingNavigationFooter(),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _TrainingHeader
    extends StatelessWidget {
  const _TrainingHeader();

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

      child:
      Row(
        children: [
          // ==================================================
          // ICON
          // ==================================================

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
              Icons.school_outlined,

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

          // ==================================================
          // TITLE
          // ==================================================

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  l10n?.translate('learning') ?? 'Learning',

                  style:
                  TextStyle(
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
                  l10n?.translate('training_portal') ?? 'Training Portal',

                  style:
                  TextStyle(
                    fontSize:
                    12,

                    color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

class _TrainingNavigationItem
    extends StatelessWidget {
  final IconData icon;

  final IconData selectedIcon;

  final String title;

  final bool selected;

  final VoidCallback onTap;

  const _TrainingNavigationItem({
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

      child:
      Material(
        color:
        Colors.transparent,

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        child:
        InkWell(
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
              color:
              selected
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

            child:
            Row(
              children: [
                // ==========================================
                // ICON
                // ==========================================

                Icon(
                  selected
                      ? selectedIcon
                      : icon,

                  size:
                  21,

                  color:
                  selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),

                const SizedBox(
                  width:
                  13,
                ),

                // ==========================================
                // TITLE
                // ==========================================

                Expanded(
                  child:
                  Text(
                    title,

                    style:
                    TextStyle(
                      fontSize:
                      14,

                      fontWeight:
                      selected
                          ? FontWeight.bold
                          : FontWeight.w500,

                      color:
                      selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                // ==========================================
                // ACTIVE INDICATOR
                // ==========================================

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

class _TrainingNavigationFooter
    extends StatelessWidget {
  const _TrainingNavigationFooter();

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20,
      ),

      decoration:
      BoxDecoration(
        border:
        Border(
          top:
          BorderSide(
            color:
            theme.dividerColor,
          ),
        ),
      ),

      child:
      Row(
        children: [
          Icon(
            Icons.school_outlined,

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
            'Training Operations',

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
