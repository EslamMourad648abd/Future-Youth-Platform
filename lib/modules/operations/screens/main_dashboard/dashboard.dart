import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/client_model.dart';
import '../../models/onboarding_tasks_model.dart';
import '../../repositories/onboarding_repository.dart';
import '../../widgets/client_card.dart';
import '../../../../../services/localization_service.dart';
import '../../../../../services/auth_service.dart';

class OnboardingDashboard extends StatelessWidget {
  const OnboardingDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return const _DashboardContent();
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent();
  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  final Map<String, Future<String>> _userNameCache = {};
  final OnboardingRepository _repository = OnboardingRepository();

  Future<String> _resolveUserName(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return Future.value('—');
    final cached = _userNameCache[normalizedUid];
    if (cached != null) return cached;
    final future = _loadUserName(normalizedUid);
    _userNameCache[normalizedUid] = future;
    return future;
  }

  Future<String> _loadUserName(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final username = data['username']?.toString().trim();
          if (username != null && username.isNotEmpty) return username;
          final displayName = data['displayName']?.toString().trim();
          if (displayName != null && displayName.isNotEmpty) return displayName;
          final email = data['email']?.toString().trim();
          if (email != null && email.isNotEmpty) return email;
        }
      }
    } catch (e) {
      debugPrint('Failed to resolve user $uid: $e');
    }
    return uid;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (currentUser == null) {
      return const _DashboardMessage(
        icon: Icons.lock_outline,
        title: 'Not signed in',
        message: 'Please sign in to view your onboarding dashboard.',
        isError: true,
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: StreamBuilder<List<ClientModel>>(
        stream: _repository.watchClients(),
        builder: (context, clientSnapshot) {
          if (clientSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
          }
          if (clientSnapshot.hasError) {
            return _DashboardMessage(icon: Icons.error_outline, title: 'Unable to load clients', message: '${clientSnapshot.error}', isError: true);
          }
          final myClients = (clientSnapshot.data ?? []).where((c) {
            final assigned = c.assignedTo.trim() == currentUser.uid;
            if (AuthService.isSupportAgent) {
              return assigned && _normalize(c.groupStatus) == 'closed';
            }
            return assigned;
          }).toList();
          final allClients = clientSnapshot.data ?? [];

          return StreamBuilder<List<OnboardingTaskModel>>(
            stream: _repository.watchMyTasks(),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
              }
              if (taskSnapshot.hasError) {
                return _DashboardMessage(icon: Icons.error_outline, title: 'Unable to load tasks', message: '${taskSnapshot.error}', isError: true);
              }
              return _DashboardBody(
                clients: myClients, 
                allClients: allClients, 
                tasks: taskSnapshot.data ?? [], 
                resolveUserName: _resolveUserName,
              );
            },
          );
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final List<ClientModel> clients;
  final List<ClientModel> allClients;
  final List<OnboardingTaskModel> tasks;
  final Future<String> Function(String uid) resolveUserName;

  const _DashboardBody({required this.clients, required this.allClients, required this.tasks, required this.resolveUserName});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context);

    final totalClients = clients.length;
    final activeClients = clients.where(_isClientActive).length;
    final pendingActivation = clients.where((c) => _normalize(c.activationStatus) != 'activated').length;
    final pendingVerification = clients.where((c) {
      final s = _normalize(c.verificationStatus);
      return s != 'approved' && s != 'verified';
    }).length;
    final pendingChatbot = clients.where((c) => _normalize(c.chatbotStatus) != 'activated').length;
    final openedGroups = clients.where((c) => _normalize(c.groupStatus) == 'opened').length;
    final closedGroups = clients.where((c) => _normalize(c.groupStatus) == 'closed').length;
    final completedClients = clients.where(_isClientCompleted).length;
    final inProgressClients = totalClients - completedClients;

    final tasksToday = tasks.where((t) => _isSameDay(t.createdAt, now)).length;
    final completedTasksToday = tasks.where((t) => t.status == 'Finished' && _isSameDay(t.finishedAt, now)).length;
    final activeTasks = tasks.where((t) => t.isActive).toList();
    final completedTasks = tasks.where((t) => t.status == 'Finished').length;
    final clientTasks = tasks.where((t) => t.clientId.trim().isNotEmpty).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(user: FirebaseAuth.instance.currentUser),
              const SizedBox(height: 28),
              if (!AuthService.isSupportAgent) ...[
                _SectionTitle(
                  title: AuthService.isSuperAdmin ? 'Operations Overview' : 'Onboarding Overview', 
                  subtitle: 'Live status of the clients currently assigned to you.'
                ),
                const SizedBox(height: 14),
                _MetricGrid(cards: [
                  _MetricData(title: l10n?.translate('my_clients') ?? 'My Clients', value: '$totalClients', subtitle: 'Assigned to you', icon: Icons.people_outline, tone: _MetricTone.brand),
                  _MetricData(title: l10n?.translate('in_progress') ?? 'In Progress', value: '$inProgressClients', subtitle: 'Onboarding underway', icon: Icons.pending_actions_outlined, tone: _MetricTone.blue),
                  _MetricData(title: l10n?.translate('completed') ?? 'Completed', value: '$completedClients', subtitle: 'All stages completed', icon: Icons.check_circle_outline, tone: _MetricTone.green),
                  _MetricData(title: l10n?.translate('pending_activation') ?? 'Pending Activation', value: '$pendingActivation', subtitle: 'Activation required', icon: Icons.power_settings_new_outlined, tone: _MetricTone.orange),
                ]),
                const SizedBox(height: 16),
                _OperationalStatusCard(pendingVerification: pendingVerification, pendingChatbot: pendingChatbot, openedGroups: openedGroups, closedGroups: closedGroups, activeClients: activeClients),
                const SizedBox(height: 28),
              ],
              _SectionTitle(title: l10n?.translate('task_overview') ?? 'Task Overview', subtitle: 'Your operational workload and activity.'),
              const SizedBox(height: 14),
              _MetricGrid(cards: [
                _MetricData(title: l10n?.translate('tasks_today') ?? 'Tasks Today', value: '$tasksToday', subtitle: 'Started today', icon: Icons.today_outlined, tone: _MetricTone.brand),
                _MetricData(title: l10n?.translate('active_tasks') ?? 'Active Tasks', value: '${activeTasks.length}', subtitle: 'Currently running', icon: Icons.play_circle_outline, tone: _MetricTone.blue),
                _MetricData(title: l10n?.translate('completed_today') ?? 'Completed Today', value: '$completedTasksToday', subtitle: 'Finished today', icon: Icons.task_alt_outlined, tone: _MetricTone.green),
                _MetricData(title: l10n?.translate('total_completed') ?? 'Total Completed', value: '$completedTasks', subtitle: 'Task history', icon: Icons.done_all_outlined, tone: _MetricTone.teal),
              ]),
              const SizedBox(height: 28),
              LayoutBuilder(builder: (context, constraints) {
                if (AuthService.isSupportAgent) {
                  return _ActiveTasksCard(tasks: activeTasks);
                }
                if (constraints.maxWidth < 900) {
                  return Column(children: [_RecentClientsCard(clients: clients, resolveUserName: resolveUserName), const SizedBox(height: 20), _ActiveTasksCard(tasks: activeTasks)]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: _RecentClientsCard(clients: clients, resolveUserName: resolveUserName)),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _ActiveTasksCard(tasks: activeTasks)),
                ]);
              }),
              const SizedBox(height: 28),
              _TaskTypeCard(tasks: tasks, clientTasks: clientTasks),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final User? user;
  const _DashboardHeader({required this.user});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _displayUserName(user);
    final l10n = AppLocalizations.of(context);
    final label = AuthService.isSupportAgent 
      ? 'Support' 
      : (AuthService.isSuperAdmin ? 'Operations' : 'Onboarding');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${l10n?.translate('welcome') ?? 'Welcome'}, $name', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 6),
        Text('Here is your $label workload and client status.', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title, subtitle;
  const _SectionTitle({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
      const SizedBox(height: 4),
      Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
    ]);
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricData> cards;
  const _MetricGrid({required this.cards});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      int columns = constraints.maxWidth >= 1400 ? 5 : constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 600 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: cards.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: columns == 1 ? 4.5 : (columns == 5 ? 2.0 : 2.35)),
        itemBuilder: (context, index) => _MetricCard(data: cards[index]),
      );
    });
  }
}

enum _MetricTone { brand, blue, green, orange, teal }

class _MetricData {
  final String title, value, subtitle;
  final IconData icon;
  final _MetricTone tone;
  const _MetricData({required this.title, required this.value, required this.subtitle, required this.icon, required this.tone});
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _metricToneColors(data.tone, theme);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(11)),
            child: Icon(data.icon, color: colors.foreground, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(data.title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            Text(data.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            Text(data.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ])),
        ]),
      ),
    );
  }
}

class _OperationalStatusCard extends StatelessWidget {
  final int pendingVerification, pendingChatbot, openedGroups, closedGroups, activeClients;
  const _OperationalStatusCard({required this.pendingVerification, required this.pendingChatbot, required this.openedGroups, required this.closedGroups, required this.activeClients});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n?.translate('operational_status') ?? 'Operational Status', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(l10n?.translate('operational_status_desc') ?? 'Distribution across assigned clients.', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final items = [
              _OperationalItem(label: l10n?.translate('active_clients') ?? 'Active Clients', value: activeClients, icon: Icons.bolt_outlined, color: Colors.blue),
              _OperationalItem(label: l10n?.translate('pending_verification') ?? 'Pending Verification', value: pendingVerification, icon: Icons.verified_user_outlined, color: Colors.orange),
              _OperationalItem(label: l10n?.translate('pending_chatbot') ?? 'Pending Chatbot', value: pendingChatbot, icon: Icons.smart_toy_outlined, color: Colors.teal),
              if (!AuthService.isSupportAgent)
                _OperationalItem(label: l10n?.translate('opened_groups') ?? 'Opened Groups', value: openedGroups, icon: Icons.forum_outlined, color: Colors.green),
              _OperationalItem(label: l10n?.translate('closed_groups') ?? 'Closed Groups', value: closedGroups, icon: Icons.forum_outlined, color: Colors.grey),
            ];
            if (constraints.maxWidth < 800) {
              return Wrap(spacing: 24, runSpacing: 18, children: items.map((i) => _OperationalItemView(item: i)).toList());
            }
            return Row(children: items.map((i) => Expanded(child: _OperationalItemView(item: i))).toList());
          }),
        ]),
      ),
    );
  }
}

class _OperationalItem {
  final String label; final int value; final IconData icon; final Color color;
  const _OperationalItem({required this.label, required this.value, required this.icon, required this.color});
}

class _OperationalItemView extends StatelessWidget {
  final _OperationalItem item;
  const _OperationalItemView({required this.item});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: item.color.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
        child: Icon(item.icon, color: item.color, size: 19),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        Text('${item.value}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    ]);
  }
}

class _RecentClientsCard extends StatelessWidget {
  final List<ClientModel> clients;
  final Future<String> Function(String uid) resolveUserName;
  const _RecentClientsCard({required this.clients, required this.resolveUserName});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recent = [...clients]..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(0)).compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0)));
    final visible = recent.take(6).toList();

    return _DashboardSectionCard(
      title: l10n?.translate('recent_clients') ?? 'Recent Clients',
      subtitle: l10n?.translate('recent_clients_desc') ?? 'Latest activity on your assigned clients.',
      icon: Icons.people_outline,
      child: visible.isEmpty
          ? _InlineEmpty(message: l10n?.translate('no_assigned_clients') ?? 'No assigned clients yet.')
          : Column(children: visible.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ClientCard(client: c, resolveUserName: resolveUserName, brandColor: theme.colorScheme.primary))).toList()),
    );
  }
}

class _ActiveTasksCard extends StatelessWidget {
  final List<OnboardingTaskModel> tasks;
  const _ActiveTasksCard({required this.tasks});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = tasks.take(8).toList();
    return _DashboardSectionCard(
      title: l10n?.translate('active_tasks') ?? 'Active Tasks',
      subtitle: l10n?.translate('active_tasks_desc') ?? 'Tasks currently running.',
      icon: Icons.play_circle_outline,
      child: visible.isEmpty
          ? _InlineEmpty(message: l10n?.translate('no_active_tasks') ?? 'No active tasks right now.')
          : Column(children: visible.map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ActiveTaskRow(task: t))).toList()),
    );
  }
}

class _ActiveTaskRow extends StatelessWidget {
  final OnboardingTaskModel task;
  const _ActiveTaskRow({required this.task});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: .1), shape: BoxShape.circle),
          child: Icon(Icons.play_arrow_rounded, color: theme.colorScheme.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.task, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(_taskContext(task), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ])),
        const SizedBox(width: 8),
        _CompactStatusChip(label: task.taskType),
      ]),
    );
  }
}

class _TaskTypeCard extends StatelessWidget {
  final List<OnboardingTaskModel> tasks; final int clientTasks;
  const _TaskTypeCard({required this.tasks, required this.clientTasks});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typeCounts = <String, int>{};
    for (final t in tasks) { _increment(typeCounts, t.taskType.trim().isEmpty ? 'Other' : t.taskType.trim()); }
    final internalTasks = tasks.where((t) => t.taskType.trim().toLowerCase() == 'internal').length;

    return _DashboardSectionCard(
      title: l10n?.translate('task_distribution') ?? 'Task Distribution',
      subtitle: l10n?.translate('task_distribution_desc') ?? 'Task workload by operational type.',
      icon: Icons.assignment_outlined,
      child: Column(children: [
        LayoutBuilder(builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;
          final items = [
            _SmallSummary(label: l10n?.translate('all_tasks') ?? 'All Tasks', value: '${tasks.length}', icon: Icons.assignment_outlined),
            _SmallSummary(label: l10n?.translate('client_tasks') ?? 'Client Tasks', value: '$clientTasks', icon: Icons.business_outlined),
            _SmallSummary(label: l10n?.translate('internal') ?? 'Internal', value: '$internalTasks', icon: Icons.apartment_outlined),
          ];

          if (isCompact) {
            return Column(children: items.map((i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: i)).toList());
          }

          return Row(children: items.map((i) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: i))).toList());
        }),
        const SizedBox(height: 18),
        if (typeCounts.isEmpty) _InlineEmpty(message: l10n?.translate('no_task_history') ?? 'No task history yet.')
        else ...typeCounts.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _TaskTypeProgress(label: e.key, count: e.value, percentage: tasks.isEmpty ? 0 : e.value / tasks.length))),
      ]),
    );
  }
}

class _SmallSummary extends StatelessWidget {
  final String label, value; final IconData icon;
  const _SmallSummary({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ])),
      ]),
    );
  }
}

class _TaskTypeProgress extends StatelessWidget {
  final String label; final int count; final double percentage;
  const _TaskTypeProgress({required this.label, required this.count, required this.percentage});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
        Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(value: percentage, minHeight: 7, backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1), color: theme.colorScheme.primary),
      ),
    ]);
  }
}

class _DashboardSectionCard extends StatelessWidget {
  final String title, subtitle; final IconData icon; final Widget child;
  const _DashboardSectionCard({required this.title, required this.subtitle, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: theme.colorScheme.primary, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ])),
          ]),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ));
  }
}

class _InlineEmpty extends StatelessWidget {
  final String message;
  const _InlineEmpty({required this.message});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(children: [
        Icon(Icons.inbox_outlined, size: 34, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      ]),
    );
  }
}

class _CompactStatusChip extends StatelessWidget {
  final String label;
  const _CompactStatusChip({required this.label});
  @override
  Widget build(BuildContext context) {
    final norm = _normalize(label);
    final color = _statusColor(norm);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
      child: Text(_displayStatus(label), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  final IconData icon; final String title, message; final bool isError;
  const _DashboardMessage({required this.icon, required this.title, required this.message, required this.isError});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: isError ? theme.colorScheme.error : theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }
}

bool _isClientActive(ClientModel client) {
  final a = _normalize(client.activationStatus);
  return a == 'activated' || a == 'active';
}

bool _isClientCompleted(ClientModel client) {
  final a = _normalize(client.activationStatus);
  final v = _normalize(client.verificationStatus);
  final c = _normalize(client.chatbotStatus);
  final g = _normalize(client.groupStatus);
  return (a == 'activated' || a == 'active') && (v == 'approved' || v == 'verified') && (c == 'activated' || c == 'active') && g == 'closed';
}

String _taskContext(OnboardingTaskModel task) {
  if (task.taskType.trim().toLowerCase() == 'internal') return task.department.trim().isEmpty ? 'Internal' : task.department;
  if (task.clientName.trim().isNotEmpty && task.accNumber.trim().isNotEmpty) return '${task.clientName} • ${task.accNumber}';
  if (task.accNumber.trim().isNotEmpty) return task.accNumber;
  return task.clientName.trim().isNotEmpty ? task.clientName : 'Client task';
}

bool _isSameDay(DateTime? value, DateTime date) {
  if (value == null) return false;
  return value.year == date.year && value.month == date.month && value.day == date.day;
}

String _displayUserName(User? user) {
  if (user == null) return 'there';
  final d = user.displayName?.trim();
  if (d != null && d.isNotEmpty) return d;
  final e = user.email?.trim();
  if (e != null && e.isNotEmpty) {
    final i = e.indexOf('@');
    return i > 0 ? e.substring(0, i) : e;
  }
  return 'there';
}

String _normalize(String? value) {
  final n = value?.trim().toLowerCase() ?? '';
  if (n.isEmpty) return 'not started';
  if (n == 'not_started' || n == 'notstarted') return 'not started';
  if (n == 'in_progress' || n == 'inprogress') return 'in progress';
  if (n == 'active') return 'activated';
  if (n == 'verified') return 'approved';
  return n;
}

String _displayStatus(String? value) {
  final n = _normalize(value);
  switch (n) {
    case 'not started': return 'Not Started';
    case 'in progress': return 'In Progress';
    case 'submitted': return 'Submitted';
    case 'approved': return 'Approved';
    case 'rejected': return 'Rejected';
    case 'activated': return 'Activated';
    case 'ready': return 'Ready';
    case 'opened': return 'Opened';
    case 'closed': return 'Closed';
    default: return value?.trim() ?? 'Not Started';
  }
}

Color _statusColor(String status) {
  final n = _normalize(status);
  switch (n) {
    case 'activated': case 'approved': case 'closed': case 'completed': return Colors.green;
    case 'ready': case 'opened': return Colors.teal;
    case 'submitted': return Colors.orange;
    case 'in progress': return Colors.blue;
    case 'rejected': case 'failed': return Colors.red;
    default: return Colors.grey;
  }
}

void _increment(Map<String, int> map, String key) { map[key] = (map[key] ?? 0) + 1; }

class _MetricColors { final Color background, foreground; const _MetricColors({required this.background, required this.foreground}); }

_MetricColors _metricToneColors(_MetricTone tone, ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  switch (tone) {
    case _MetricTone.brand: 
      return _MetricColors(background: theme.colorScheme.primary.withValues(alpha: .1), foreground: theme.colorScheme.primary);
    case _MetricTone.blue: 
      return _MetricColors(
        background: isDark ? const Color(0xff2878C8).withValues(alpha: 0.1) : const Color(0xffEAF4FF), 
        foreground: isDark ? const Color(0xff60A5FA) : const Color(0xff2878C8),
      );
    case _MetricTone.green: 
      return _MetricColors(
        background: isDark ? const Color(0xff21864B).withValues(alpha: 0.1) : const Color(0xffEAF8F0), 
        foreground: isDark ? const Color(0xff4ADE80) : const Color(0xff21864B),
      );
    case _MetricTone.orange: 
      return _MetricColors(
        background: isDark ? const Color(0xffC77700).withValues(alpha: 0.1) : const Color(0xfffff4e6), 
        foreground: isDark ? const Color(0xffFBBF24) : const Color(0xffC77700),
      );
    case _MetricTone.teal: 
      return _MetricColors(
        background: isDark ? const Color(0xff168579).withValues(alpha: 0.1) : const Color(0xffE9F8F6), 
        foreground: isDark ? const Color(0xff2DD4BF) : const Color(0xff168579),
      );
  }
}
