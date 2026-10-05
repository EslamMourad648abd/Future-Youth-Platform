import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;

import '../router/app_router.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/theme_service.dart';

const Color kPlatformBrandColor =
Color(0xff003366);

class PlatformShell extends StatelessWidget {
  const PlatformShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1000;
    final l10n = AppLocalizations.of(context);

    if (isMobile) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.primary),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            l10n?.translate('bevatel_operations') ?? 'BEVATEL',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          shape: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        drawer: Drawer(
          width: _PlatformSidebar.width,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: _PlatformSidebar(
            location: location,
            user: user,
            isDrawer: true,
          ),
        ),
        body: child,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Row(
          children: [
            _PlatformSidebar(
              location: location,
              user: user,
            ),
            Expanded(
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SIDEBAR
// ============================================================

class _PlatformSidebar extends StatelessWidget {
  const _PlatformSidebar({
    required this.location,
    required this.user,
    this.isDrawer = false,
  });

  final String location;
  final User? user;
  final bool isDrawer;

  static const double width = 260;

  void _logout(
      BuildContext context,
      ) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) {
        return;
      }

      context.go(
        AppRouter.login,
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text('Failed to logout: $e'),
          backgroundColor:
          Colors.redAccent,
        ),
      );
    }
  }

  void _openAdminConsole() {
    html.window.open(
      '#${AppRouter.adminConsole}',
      '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: width,

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,

        border: isDrawer ? null : Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,

        children: [
          const _PlatformHeader(),

          const SizedBox(
            height: 12,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 12,
              ),

              child: Column(
                children: [
                  // ==================================================
                  // DASHBOARD
                  // ==================================================

                  _PlatformNavItem(
                    icon:
                    Icons.dashboard_outlined,

                    selectedIcon:
                    Icons.dashboard,

                    title:
                    l10n?.translate('dashboard') ?? 'Dashboard',

                    selected:
                    location ==
                        AppRouter.home,

                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      context.go(
                        AppRouter.home,
                      );
                    },
                  ),

                  // ==================================================
                  // BBC API
                  // ==================================================

                  if (AuthService.isSuperAdmin ||
                      AuthService.isAgent ||
                      AuthService.isTrainee)
                    _PlatformNavItem(
                      icon:
                      Icons.api_outlined,

                      selectedIcon:
                      Icons.api,

                      title:
                      l10n?.translate('bbc_api_tool') ?? 'BBC API Tool',

                      selected:
                      location ==
                          AppRouter.bbcApi ||
                          location.startsWith(
                            '${AppRouter.bbcApi}/',
                          ),

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(
                          AppRouter.bbcApi,
                        );
                      },
                    ),

                  // ==================================================
                  // TRAINING
                  // ==================================================

                  if (AuthService.isSuperAdmin ||
                      AuthService.isTrainee)
                    _PlatformNavItem(
                      icon:
                      Icons.school_outlined,

                      selectedIcon:
                      Icons.school,

                      title:
                      l10n?.translate('training_portal') ?? 'Training Portal',

                      selected:
                      location ==
                          AppRouter.training ||
                          location.startsWith(
                            '${AppRouter.training}/',
                          ),

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(
                          AppRouter.training,
                        );
                      },
                    ),

                  // ==================================================
                  // ONBOARDING
                  // ==================================================

                  if (AuthService.isSuperAdmin ||
                      AuthService.isAgent)
                    _PlatformNavItem(
                      icon:
                      Icons.business_center_outlined,

                      selectedIcon:
                      Icons.business_center,

                      title:
                      l10n?.translate('onboarding') ?? 'Onboarding',

                      selected:
                      location ==
                          AppRouter.onboarding ||
                          location.startsWith(
                            '${AppRouter.operations}/',
                          ),

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(
                          AppRouter.onboarding,
                        );
                      },
                    ),

                  // ==================================================
                  // ADMIN CONSOLE
                  // ==================================================

                  if (AuthService.isSuperAdmin) ...[
                    const SizedBox(
                      height: 16,
                    ),

                    const Divider(
                      color:
                      Color(0xffE5EAF0),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _PlatformNavItem(
                      icon:
                      Icons.admin_panel_settings_outlined,

                      selectedIcon:
                      Icons.admin_panel_settings,

                      title:
                      l10n?.translate('admin_console') ?? 'Admin Console',

                      selected:
                      false,

                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        _openAdminConsole();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ==================================================
          // ACCOUNT FOOTER
          // ==================================================

          _PlatformFooter(
            user: user,
            onLogout: () {
              if (isDrawer) Navigator.pop(context);
              _logout(context);
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _PlatformHeader
    extends StatelessWidget {
  const _PlatformHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        12,
      ),

      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,

                decoration:
                BoxDecoration(
                  color:
                  kPlatformBrandColor
                      .withValues(alpha: 0.08),

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),

                child: const Icon(
                  Icons.business_outlined,
                  color:
                  kPlatformBrandColor,
                  size: 23,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      'BEVATEL',
                      style:
                      TextStyle(
                        fontSize: 17,
                        fontWeight:
                        FontWeight.w700,
                        color:
                        theme.colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    const Text(
                      'Operations Platform',
                      style:
                      TextStyle(
                        fontSize: 12,
                        color:
                        Color(0xff7A8491),
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NAVIGATION ITEM
// ============================================================

class _PlatformNavItem
    extends StatelessWidget {
  const _PlatformNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;

  final String title;

  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 4,
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
              milliseconds: 180,
            ),

            padding:
            const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),

            decoration:
            BoxDecoration(
              color: selected
                  ? kPlatformBrandColor
                  .withValues(alpha: 0.08)
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

                  size: 21,

                  color: selected
                      ? kPlatformBrandColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),

                const SizedBox(
                  width: 13,
                ),

                Expanded(
                  child: Text(
                    title,

                    style:
                    TextStyle(
                      fontSize: 14,

                      fontWeight:
                      selected
                          ? FontWeight.w600
                          : FontWeight.w500,

                      color: selected
                          ? kPlatformBrandColor
                          : const Color(
                        0xff4D5763,
                      ),
                    ),
                  ),
                ),

                if (selected)
                  Container(
                    width: 4,
                    height: 22,

                    decoration:
                    BoxDecoration(
                      color:
                      kPlatformBrandColor,

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

class _PlatformFooter
    extends StatelessWidget {
  const _PlatformFooter({
    required this.user,
    required this.onLogout,
  });

  final User? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name =
    user?.displayName
        ?.isNotEmpty ==
        true
        ? user!.displayName!
        : (user?.email ??
        'Unknown User');

    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20,
      ),

      decoration:
      const BoxDecoration(
        border: Border(
          top: BorderSide(
            color:
            Color(0xffE5EAF0),
          ),
        ),
      ),

      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,

            backgroundColor:
            kPlatformBrandColor,

            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 19,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  name,

                  maxLines: 1,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  AuthService.role
                      .toUpperCase(),

                  style:
                  const TextStyle(
                    fontSize: 10,
                    color:
                    Color(0xff7A8491),
                  ),
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            padding:
            EdgeInsets.zero,

            icon:
            const Icon(
              Icons.more_vert,
              size: 20,
              color:
              Color(0xff7A8491),
            ),

            onSelected:
                (value) {
              if (value ==
                  'logout') {
                onLogout();
              }
            },

            itemBuilder:
                (context) => [
              PopupMenuItem(
                value:
                'logout',

                child: ListTile(
                  leading:
                  const Icon(
                    Icons.logout,
                  ),

                  title:
                  Text(
                    l10n?.translate('logout') ?? 'Logout',
                  ),

                  contentPadding:
                  EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}