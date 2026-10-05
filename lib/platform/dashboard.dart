import 'dart:html' as html;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/theme_service.dart';
import '../services/platform_config.dart';

class PlatformDashboard extends StatelessWidget {
  const PlatformDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      context.go(AppRouter.login);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to logout: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1000;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: isMobile ? AppBar(
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
          l10n?.translate('bevatel') ?? 'BEVATEL',
          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
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
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
      ) : null,
      drawer: isMobile ? Drawer(
        width: _PlatformSidebar.width,
        child: _PlatformSidebar(
          user: user,
          isDrawer: true,
          onLogout: () {
            Navigator.pop(context);
            _logout(context);
          },
        ),
      ) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile)
              _PlatformSidebar(
                user: user,
                onLogout: () => _logout(context),
              ),
            Expanded(
              child: _PlatformDashboardContent(user: user),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformSidebar extends StatelessWidget {
  const _PlatformSidebar({required this.user, required this.onLogout, this.isDrawer = false});
  final User? user;
  final VoidCallback onLogout;
  final bool isDrawer;
  static const double width = 260;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final config = PlatformConfig.current;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: isDrawer ? null : Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PlatformHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  _PlatformNavigationItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    title: l10n?.translate('dashboard') ?? 'Dashboard',
                    selected: location == AppRouter.home,
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      context.go(AppRouter.home);
                    },
                  ),
                  if ((AuthService.isSuperAdmin || AuthService.isAgent || AuthService.isTrainee) && 
                      (!config.isStandalone || config.type == PlatformType.apiTool))
                    _PlatformNavigationItem(
                      icon: Icons.api_outlined,
                      selectedIcon: Icons.api,
                      title: l10n?.translate('bbc_api_tool') ?? 'BBC API Tool',
                      selected: location == AppRouter.bbcApi || location.startsWith('${AppRouter.bbcApi}/'),
                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(AppRouter.bbcApi);
                      },
                    ),
                  if ((AuthService.isSuperAdmin || AuthService.isTrainee) && 
                      (!config.isStandalone || config.type == PlatformType.trainee))
                    _PlatformNavigationItem(
                      icon: Icons.school_outlined,
                      selectedIcon: Icons.school,
                      title: l10n?.translate('training_portal') ?? 'Training Portal',
                      selected: location == AppRouter.training || location.startsWith('${AppRouter.training}/'),
                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(AppRouter.training);
                      },
                    ),
                  if ((AuthService.isSuperAdmin || AuthService.isAgent || AuthService.isSupportAgent) && 
                      (!config.isStandalone || config.type == PlatformType.support || config.type == PlatformType.onboarding))
                    _PlatformNavigationItem(
                      icon: Icons.business_center_outlined,
                      selectedIcon: Icons.business_center,
                      title: AuthService.isSupportAgent
                          ? (l10n?.translate('support') ?? 'Support')
                          : AuthService.isSuperAdmin
                              ? (l10n?.translate('operations') ?? 'Operations')
                              : (l10n?.translate('onboarding') ?? 'Onboarding'),
                      selected: location == AppRouter.operations || location.startsWith('${AppRouter.operations}/'),
                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        context.go(AppRouter.onboarding);
                      },
                    ),
                ],
              ),
            ),
          ),
          _PlatformSidebarFooter(user: user, onLogout: onLogout),
        ],
      ),
    );
  }
}

class _PlatformHeader extends StatelessWidget {
  const _PlatformHeader();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.apps_outlined, color: theme.colorScheme.primary, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.translate('bevatel') ?? 'BEVATEL',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                Text(
                  AuthService.isSupportAgent
                      ? (l10n?.translate('Support Platform') ?? 'Support Platform')
                      : AuthService.isSuperAdmin
                          ? (l10n?.translate('Operations Platform') ?? 'Operations Platform')
                          : (l10n?.translate('Onboarding Platform') ?? 'Onboarding Platform'),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                iconSize: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlatformNavigationItem extends StatelessWidget {
  const _PlatformNavigationItem({required this.icon, required this.selectedIcon, required this.title, required this.selected, required this.onTap});
  final IconData icon, selectedIcon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(selected ? selectedIcon : icon, size: 21, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
                  ),
                ),
                if (selected) Container(width: 4, height: 18, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformSidebarFooter extends StatelessWidget {
  const _PlatformSidebarFooter({required this.user, required this.onLogout});
  final User? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = user?.displayName ?? user?.email ?? 'User';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 18, backgroundColor: theme.colorScheme.primary, child: const Icon(Icons.person, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(AuthService.role.toUpperCase(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (AuthService.isSuperAdmin)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => html.window.open('#${AppRouter.adminConsole}', '_blank'),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: Text(l10n?.translate('admin_console') ?? 'Admin Console'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ),
          if (AuthService.isSuperAdmin) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: Text(l10n?.translate('logout') ?? 'Logout'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformDashboardContent extends StatelessWidget {
  const _PlatformDashboardContent({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = user?.displayName ?? 'there';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n?.translate('welcome') ?? 'Welcome'}, $name', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(l10n?.translate('manage_platforms') ?? 'Manage platforms from here.', style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 36),
              Text(l10n?.translate('platform_overview') ?? 'Platform Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
                final config = PlatformConfig.current;

                return GridView.count(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns, crossAxisSpacing: 20, mainAxisSpacing: 20,
                  childAspectRatio: columns == 1 ? 3.5 : 1.7,
                  children: [
                    if ((AuthService.isSuperAdmin || AuthService.isAgent || AuthService.isTrainee) && 
                        (!config.isStandalone || config.type == PlatformType.apiTool))
                      _PlatformOverviewCard(title: l10n?.translate('bbc_api_tool') ?? 'BBC API Tool', subtitle: 'API Testing', icon: Icons.api, status: l10n?.translate('available') ?? 'Available'),
                    if ((AuthService.isSuperAdmin || AuthService.isTrainee) && 
                        (!config.isStandalone || config.type == PlatformType.trainee))
                      _PlatformOverviewCard(title: l10n?.translate('training_portal') ?? 'Training Portal', subtitle: 'Learning', icon: Icons.school, status: l10n?.translate('available') ?? 'Available'),
                    if ((AuthService.isSuperAdmin || AuthService.isAgent || AuthService.isSupportAgent) && 
                        (!config.isStandalone || config.type == PlatformType.support || config.type == PlatformType.onboarding))
                      _PlatformOverviewCard(
                        title: AuthService.isSupportAgent
                            ? (l10n?.translate('support') ?? 'Support')
                            : AuthService.isSuperAdmin
                                ? (l10n?.translate('Operations platform') ?? 'Operations platform')
                                : (l10n?.translate('Onboarding platform') ?? 'Onboarding platform'),
                        subtitle: 'Client Management',
                        icon: Icons.business_center,
                        status: l10n?.translate('available') ?? 'Available',
                      ),
                  ],
                );
              }),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
                        child: Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n?.translate('navigation') ?? 'Navigation', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(l10n?.translate('navigation_desc') ?? 'Use sidebar to switch platforms.', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformOverviewCard extends StatelessWidget {
  const _PlatformOverviewCard({required this.title, required this.subtitle, required this.icon, required this.status});
  final String title, subtitle, status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: theme.colorScheme.primary, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
