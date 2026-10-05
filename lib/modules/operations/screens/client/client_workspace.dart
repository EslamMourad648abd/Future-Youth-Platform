import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../../router/app_router.dart';
import '../../../../../services/localization_service.dart';
import '../../models/client_model.dart';
import '../../repositories/onboarding_repository.dart';

class ClientWorkspace extends StatefulWidget {
  const ClientWorkspace({
    super.key,
    required this.clientId,
    required this.child,
  });

  final String clientId;
  final Widget child;

  @override
  State<ClientWorkspace> createState() => _ClientWorkspaceState();
}

class _ClientWorkspaceState extends State<ClientWorkspace> {
  late final Stream<ClientModel?> _clientStream;

  bool _isAgent = false;

  @override
  void initState() {
    super.initState();

    _clientStream = OnboardingRepository().watchClient(widget.clientId);

    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final token = await user.getIdTokenResult();

    if (!mounted) return;

    final role = (token.claims?['role'] ?? '').toString().trim().toLowerCase();

    setState(() {
      _isAgent =
          role == 'onboarding_agent' ||
          role == 'support_agent' ||
          role == 'agent';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<ClientModel?>(
      stream: _clientStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Scaffold(body: Center(child: CircularProgressIndicator()));

        if (snapshot.hasError)
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );

        final client = snapshot.data;

        if (client == null)
          return Scaffold(
            body: Center(
              child: Text(l10n?.translate('client_not_found') ?? 'Not found.'),
            ),
          );

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: SafeArea(
            child: Column(
              children: [
                _ClientWorkspaceHeader(client: client),
                _ClientWorkspaceTabs(
                  clientId: widget.clientId,
                  location: GoRouterState.of(context).uri.path,
                  client: client,
                  isAgent: _isAgent,
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClientWorkspaceHeader extends StatelessWidget {
  const _ClientWorkspaceHeader({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;

        return Container(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 24,
            18,
            isMobile ? 12 : 24,
            18,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.go(AppRouter.onboardingClients),
                icon: const Icon(Icons.arrow_back, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              if (!isMobile) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.business_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      client.companyName.isEmpty
                          ? (l10n?.translate('client_workspace') ?? 'Workspace')
                          : client.companyName,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      client.accNumber.isEmpty
                          ? 'ID: ${client.id}'
                          : '${l10n?.translate('acc') ?? 'ACC'}: ${client.accNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ClientStatusBadge(status: client.activationStatus),
            ],
          ),
        );
      },
    );
  }
}

class _ClientStatusBadge extends StatelessWidget {
  const _ClientStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final n = status.trim().toLowerCase();

    Color c = Colors.orange;

    if (n == 'activated' || n == 'active') {
      c = Colors.green;
    } else if (n == 'failed' || n == 'blocked' || n == 'rejected') {
      c = Colors.red;
    } else if (n == 'in progress') {
      c = Colors.blue;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isVerySmall = screenWidth < 400;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isVerySmall ? 8 : 12,
            vertical: isVerySmall ? 4 : 7,
          ),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: isVerySmall ? 6 : 8, color: c),
              SizedBox(width: isVerySmall ? 4 : 7),
              Text(
                status.isEmpty ? 'Not Started' : status,
                style: TextStyle(
                  fontSize: isVerySmall ? 10 : 12,
                  fontWeight: FontWeight.bold,
                  color: c,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClientWorkspaceTabs extends StatelessWidget {
  const _ClientWorkspaceTabs({
    required this.clientId,
    required this.location,
    required this.client,
    required this.isAgent,
  });

  final String clientId;
  final String location;
  final ClientModel client;
  final bool isAgent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final actStat = client.activationStatus.trim().toLowerCase();
    final verStat = client.verificationStatus.trim().toLowerCase();
    final chatStat = client.chatbotStatus.trim().toLowerCase();
    final grpStat = client.groupStatus.trim().toLowerCase();

    final tabs = [
      _TabInfo(
        l10n?.translate('overview') ?? 'Overview',
        Icons.dashboard_outlined,
        Icons.dashboard,
        AppRouter.clientOverviewPath(clientId),
      ),

      // Agents only see Activation while it is still pending/in progress.
      // Super Admin always sees the tab.
      if (!isAgent || (actStat != 'activated' && actStat != 'active'))
        _TabInfo(
          l10n?.translate('activation') ?? 'Activation',
          Icons.power_settings_new_outlined,
          Icons.power_settings_new,
          AppRouter.clientActivationPath(clientId),
        ),

      _TabInfo(
        l10n?.translate('channels') ?? 'Channels',
        Icons.hub_outlined,
        Icons.hub,
        AppRouter.clientChannelsPath(clientId),
      ),

      // Agents only see Verification while it is still pending/in progress.
      // Super Admin always sees the tab.
      if (!isAgent || (verStat != 'approved' && verStat != 'verified'))
        _TabInfo(
          l10n?.translate('verification') ?? 'Verification',
          Icons.verified_outlined,
          Icons.verified,
          AppRouter.clientVerificationPath(clientId),
        ),

      // Agents only see Chatbot while it is still pending/in progress.
      // Super Admin always sees the tab.
      if (!isAgent || (chatStat != 'activated' && chatStat != 'active'))
        _TabInfo(
          l10n?.translate('chatbot') ?? 'Chatbot',
          Icons.smart_toy_outlined,
          Icons.smart_toy,
          AppRouter.clientChatbotPath(clientId),
        ),

      // Agents only see Group while it is not closed.
      // Super Admin always sees the tab.
      if (!isAgent || grpStat != 'closed')
        _TabInfo(
          l10n?.translate('group') ?? 'Group',
          Icons.groups_outlined,
          Icons.groups,
          AppRouter.clientGroupPath(clientId),
        ),

      _TabInfo(
        l10n?.translate('activity') ?? 'Activity',
        Icons.history_outlined,
        Icons.history,
        AppRouter.clientActivityPath(clientId),
      ),
    ];

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              tabs.map((t) {
                final s = location == t.path;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => context.go(t.path),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                s
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s ? t.selIcon : t.icon,
                            size: 19,
                            color:
                                s
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: s ? FontWeight.bold : FontWeight.w500,
                              color:
                                  s
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}

class _TabInfo {
  final String title;
  final IconData icon;
  final IconData selIcon;
  final String path;

  _TabInfo(this.title, this.icon, this.selIcon, this.path);
}
