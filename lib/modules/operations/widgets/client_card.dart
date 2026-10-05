import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/client_model.dart';
import '../../../../services/localization_service.dart';
import '../../../../services/auth_service.dart';

class ClientCard extends StatelessWidget {
  final ClientModel client;
  final Future<String> Function(String uid)? resolveUserName;
  final Color? brandColor;
  final VoidCallback? onDelete;

  const ClientCard({super.key, required this.client, this.resolveUserName, this.brandColor, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = brandColor ?? theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: theme.dividerColor)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/operations/onboarding/client/${Uri.encodeComponent(client.id)}'),
        child: LayoutBuilder(builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 800;
          final isNarrow = constraints.maxWidth < 500;

          final iconPart = Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.business_outlined, color: primary),
          );

          final titlePart = Expanded(
            flex: isCompact ? 0 : 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.companyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text('${l10n?.translate('acc') ?? 'ACC'}: ${client.accNumber}', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                Text('${l10n?.translate('system') ?? 'System'}: ${client.systemType}', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
              ],
            ),
          );

          final statusPart = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(label: l10n?.translate('activation') ?? 'Activation', status: client.activationStatus),
              StatusChip(label: l10n?.translate('verification') ?? 'Verification', status: client.verificationStatus),
              StatusChip(label: l10n?.translate('chatbot') ?? 'Chatbot', status: client.chatbotStatus),
              StatusChip(label: l10n?.translate('group') ?? 'Group', status: client.groupStatus),
            ],
          );

          final metaPart = SizedBox(
            width: isCompact ? null : 150,
            child: Column(
              crossAxisAlignment: isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: isCompact ? MainAxisAlignment.start : MainAxisAlignment.end,
                  children: [
                    Icon(Icons.hub_outlined, size: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 5),
                    Text('${l10n?.translate('channels') ?? 'Channels'}: ${client.totalChannels}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                if (resolveUserName != null && !AuthService.isSupportAgent)
                  FutureBuilder<String>(
                    future: resolveUserName!(client.assignedTo),
                    builder: (context, snapshot) => Text(
                      '${l10n?.translate('assigned') ?? 'Assigned'}: ${snapshot.data ?? '...'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
          );

          final actionsPart = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: l10n?.translate('delete') ?? 'Delete',
                ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          );

          if (isCompact) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [iconPart, const SizedBox(width: 16), titlePart, const Spacer(), actionsPart]),
                  const SizedBox(height: 18),
                  statusPart,
                  const SizedBox(height: 18),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  metaPart,
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                iconPart,
                const SizedBox(width: 16),
                titlePart,
                const SizedBox(width: 20),
                Expanded(flex: 4, child: statusPart),
                const SizedBox(width: 20),
                metaPart,
                const SizedBox(width: 12),
                actionsPart,
              ],
            ),
          );
        }),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label, status;
  const StatusChip({super.key, required this.label, required this.status});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final norm = status.trim().toLowerCase();
    Color c = Colors.grey;
    if (norm == 'activated' || norm == 'active' || norm == 'approved' || norm == 'closed' || norm == 'ready') c = Colors.green;
    else if (norm == 'in progress' || norm == 'in_progress' || norm == 'opened') c = Colors.blue;
    else if (norm == 'submitted' || norm == 'pending') c = Colors.orange;
    else if (norm == 'rejected' || norm == 'failed') c = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: .2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: c),
        const SizedBox(width: 5),
        Text('$label: ${_displayStatus(norm, l10n)}', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }
  String _displayStatus(String n, AppLocalizations? l) {
    if (n.isEmpty || n == 'not started') return l?.translate('not_started_status') ?? 'Not Started';
    final translated = l?.translate('${n.replaceAll(' ', '_')}_status');
    return translated != null && translated.contains('_status') ? n.toUpperCase() : translated ?? n.toUpperCase();
  }
}
