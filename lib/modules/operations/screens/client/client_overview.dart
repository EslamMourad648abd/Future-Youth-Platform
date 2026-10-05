import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/client_model.dart';
import '../../repositories/onboarding_repository.dart';
import '../../services/crm_service.dart';
import '../../../../../services/localization_service.dart';
import '../../../../../services/user_display_name_resolver.dart';

class ClientOverviewScreen extends StatelessWidget {
  final String clientId;
  const ClientOverviewScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<ClientModel?>(
      stream: OnboardingRepository().watchClient(clientId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (snap.hasError || snap.data == null) return _Msg(icon: Icons.error_outline, title: 'Error', message: 'Not found.');
        final cl = snap.data!;
        return Container(color: theme.colorScheme.surface, child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1250), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header(client: cl), const SizedBox(height: 24),
          _StatusGrid(client: cl), const SizedBox(height: 28),
          LayoutBuilder(builder: (c, cs) => cs.maxWidth < 850 ? Column(children: [_InfoCard(client: cl), const SizedBox(height: 20), _OwnerCard(client: cl)]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _InfoCard(client: cl)), const SizedBox(width: 20), Expanded(flex: 2, child: _OwnerCard(client: cl))])),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (c, cs) => cs.maxWidth < 850 ? Column(children: [_IntegrationCard(client: cl), const SizedBox(height: 20), _GroupCard(client: cl)]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _IntegrationCard(client: cl)), const SizedBox(width: 20), Expanded(flex: 2, child: _GroupCard(client: cl))])),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (c, cs) => cs.maxWidth < 850 ? Column(children: [_ChannelsCard(client: cl), const SizedBox(height: 20), _CrmCommentCard(client: cl)]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _ChannelsCard(client: cl)), const SizedBox(width: 20), Expanded(flex: 2, child: _CrmCommentCard(client: cl))])),
          const SizedBox(height: 28),
          _TimelineInfo(client: cl),
        ])))));
      },
    );
  }
}

class _Header extends StatelessWidget {
  final ClientModel client; const _Header({required this.client});
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Row(children: [
      Container(width: 54, height: 54, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.business_outlined, color: theme.colorScheme.primary, size: 26)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l?.translate('overview') ?? 'Overview', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(client.companyName.isEmpty ? 'Unnamed Client' : client.companyName, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        Text('${l?.translate('acc') ?? 'ACC'}: ${client.accNumber}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
      ])),
    ]);
  }
}

class _StatusGrid extends StatelessWidget {
  final ClientModel client; const _StatusGrid({required this.client});
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = [
      _SData(l?.translate('activation') ?? 'Activation', client.activationStatus, Icons.power_settings_new_outlined),
      _SData(l?.translate('verification') ?? 'Verification', client.verificationStatus, Icons.verified_user_outlined),
      _SData(l?.translate('chatbot') ?? 'Chatbot', client.chatbotStatus, Icons.smart_toy_outlined),
      _SData(l?.translate('group') ?? 'Group', client.groupStatus, Icons.groups_outlined),
    ];
    return LayoutBuilder(builder: (c, cs) {
      int cols = cs.maxWidth >= 1100 ? 4 : cs.maxWidth >= 650 ? 2 : 1;
      return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2.5), itemBuilder: (c, i) => _StatusCard(data: items[i]));
    });
  }
}

class _SData { final String t, v; final IconData i; _SData(this.t, this.v, this.i); }
class _StatusCard extends StatelessWidget {
  final _SData data; const _StatusCard({required this.data});
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context); final st = _statusStyle(data.v);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(10)), child: Icon(data.i, color: st.fg, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(data.t, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        Text(data.v.isEmpty ? 'Not Started' : data.v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ])));
  }
}

class _InfoCard extends StatelessWidget {
  final ClientModel client; const _InfoCard({required this.client});
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Section(
      title: l?.translate('client_info') ?? 'Information',
      icon: Icons.info_outline,
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        onPressed: () => _showEditDialog(context),
        tooltip: l?.translate('edit_client_info') ?? 'Edit Information',
      ),
      child: Column(children: [
        _Row(l?.translate('company_name') ?? 'Name', client.companyName),
        _Row(l?.translate('acc') ?? 'ACC', client.accNumber),
        _Row(l?.translate('system') ?? 'System', client.systemType),
        _Row('ID', client.id),
      ]),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cc = TextEditingController(text: client.companyName);
    final ac = TextEditingController(text: client.accNumber);
    String st = client.systemType;

    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: Text(l?.translate('edit_client_info') ?? 'Edit Client Information'),
          content: SizedBox(
            width: 450,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: cc, decoration: InputDecoration(labelText: l?.translate('company_name') ?? 'Company')),
              const SizedBox(height: 16),
              TextField(controller: ac, decoration: InputDecoration(labelText: l?.translate('acc') ?? 'ACC')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: st,
                decoration: InputDecoration(labelText: l?.translate('system') ?? 'System'),
                items: const [DropdownMenuItem(value: 'New', child: Text('New')), DropdownMenuItem(value: 'Old', child: Text('Old'))],
                onChanged: (v) { if (v != null) setS(() => st = v); },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(l?.translate('cancel') ?? 'Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (cc.text.trim().isEmpty || ac.text.trim().isEmpty) return;
                final repo = OnboardingRepository();
                final Map<String, dynamic> updates = {};
                final Map<String, dynamic> logMetadata = {};
                
                if (cc.text.trim() != client.companyName) {
                  updates['companyName'] = cc.text.trim();
                  logMetadata['companyName'] = {'old': client.companyName, 'new': cc.text.trim()};
                }
                if (ac.text.trim() != client.accNumber) {
                  updates['accNumber'] = ac.text.trim();
                  logMetadata['accNumber'] = {'old': client.accNumber, 'new': ac.text.trim()};
                }
                if (st != client.systemType) {
                  updates['systemType'] = st;
                  logMetadata['systemType'] = {'old': client.systemType, 'new': st};
                }

                if (updates.isNotEmpty) {
                  try {
                    await repo.updateClientFields(client.id, updates);
                    await repo.addActivity(
                      clientId: client.id, type: 'client_updated', action: 'edit_info',
                      title: 'Client information updated',
                      description: 'General information fields were updated.',
                      metadata: logMetadata,
                    );
                    if (context.mounted) {
                      Navigator.pop(c);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l?.translate('client_info_updated') ?? 'Client updated.')));
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
                  }
                } else {
                  Navigator.pop(c);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
              child: Text(l?.translate('save_changes') ?? 'Save'),
            ),
          ],
        ),
      ),
    );
    cc.dispose(); ac.dispose();
  }
}

class _OwnerCard extends StatelessWidget {
  final ClientModel client; const _OwnerCard({required this.client});
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); final r = UserDisplayNameResolver();
    return _Section(title: l?.translate('ownership') ?? 'Ownership', icon: Icons.person_outline, child: Column(children: [
      _UserRow(l?.translate('assigned_to') ?? 'Assigned', client.assignedTo, r),
      _UserRow(l?.translate('created_by') ?? 'Created', client.createdBy, r),
    ]));
  }
}

class _IntegrationCard extends StatelessWidget {
  final ClientModel client; const _IntegrationCard({required this.client});
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Section(
      title: l?.translate('integration_details') ?? 'Integration',
      icon: Icons.settings_input_component,
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        onPressed: () => _showEditDialog(context),
        tooltip: 'Edit Integration',
      ),
      child: Column(children: [
        _Row('BM ID', client.bmId), _Row('WABA ID', client.wabaId),
        _Row(l?.translate('phone_number_id') ?? 'Phone ID', client.phoneNumberId),
        _Row(l?.translate('phone_number') ?? 'Phone', client.phoneNumber),
      ]),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bmc = TextEditingController(text: client.bmId);
    final wac = TextEditingController(text: client.wabaId);
    final pic = TextEditingController(text: client.phoneNumberId);
    final pnc = TextEditingController(text: client.phoneNumber);

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Integration Details'),
        content: SizedBox(
          width: 450,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: bmc, decoration: const InputDecoration(labelText: 'BM ID')),
            const SizedBox(height: 16),
            TextField(controller: wac, decoration: const InputDecoration(labelText: 'WABA ID')),
            const SizedBox(height: 16),
            TextField(controller: pic, decoration: InputDecoration(labelText: l?.translate('phone_number_id') ?? 'Phone ID')),
            const SizedBox(height: 16),
            TextField(controller: pnc, decoration: InputDecoration(labelText: l?.translate('phone_number') ?? 'Phone Number')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l?.translate('cancel') ?? 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final repo = OnboardingRepository();
              final Map<String, dynamic> updates = {};
              final Map<String, dynamic> logMetadata = {};

              void check(String key, String oldV, String newV) {
                if (oldV != newV) {
                  updates[key] = newV;
                  logMetadata[key] = {'old': oldV, 'new': newV};
                }
              }

              check('bmId', client.bmId, bmc.text.trim());
              check('wabaId', client.wabaId, wac.text.trim());
              check('phoneNumberId', client.phoneNumberId, pic.text.trim());
              check('phoneNumber', client.phoneNumber, pnc.text.trim());

              if (updates.isNotEmpty) {
                try {
                  await repo.updateClientFields(client.id, updates);
                  await repo.addActivity(
                    clientId: client.id, type: 'integration_updated', action: 'edit_integration',
                    title: 'Integration details updated',
                    description: 'Client integration IDs and phone details were updated.',
                    metadata: logMetadata,
                  );
                  if (context.mounted) Navigator.pop(c);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
                }
              } else {
                Navigator.pop(c);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
            child: Text(l?.translate('save_changes') ?? 'Save'),
          ),
        ],
      ),
    );
    bmc.dispose(); wac.dispose(); pic.dispose(); pnc.dispose();
  }
}

class _GroupCard extends StatelessWidget {
  final ClientModel client; const _GroupCard({required this.client});
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Section(
      title: l?.translate('group_info') ?? 'Group',
      icon: Icons.groups_outlined,
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        onPressed: () => _showEditDialog(context),
        tooltip: 'Edit Group Days',
      ),
      child: Column(children: [
        _Row(l?.translate('status') ?? 'Status', client.groupStatus),
        _Row('Duration (Days)', '${client.groupDurationDays ?? 0}'),
        _Row(l?.translate('opened') ?? 'Opened', _fDate(client.groupOpenedAt)),
        _Row(l?.translate('closed') ?? 'Closed', _fDate(client.groupClosedAt)),
      ]),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dc = TextEditingController(text: '${client.groupDurationDays ?? 0}');

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Group Duration'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: dc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (Days)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l?.translate('cancel') ?? 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(dc.text.trim()) ?? 0;
              if (val != client.groupDurationDays) {
                try {
                  final repo = OnboardingRepository();
                  await repo.updateClientFields(client.id, {'groupDurationDays': val});
                  await repo.addActivity(
                    clientId: client.id, type: 'group', action: 'edit_duration',
                    title: 'Group duration updated',
                    description: 'Group duration was changed to $val days.',
                    metadata: {'oldValue': client.groupDurationDays, 'newValue': val},
                  );
                  if (context.mounted) Navigator.pop(c);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
                }
              } else {
                Navigator.pop(c);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
            child: Text(l?.translate('save_changes') ?? 'Save'),
          ),
        ],
      ),
    );
    dc.dispose();
  }
}

class _ChannelsCard extends StatelessWidget {
  final ClientModel client; const _ChannelsCard({required this.client});
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); final theme = Theme.of(context);
    return _Section(title: l?.translate('integrated_channels') ?? 'Channels', icon: Icons.hub_outlined, trailing: Text('${client.channelCount}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)), child: client.channels.isEmpty ? Text('No channels.', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))) : Column(children: client.channels.take(3).map((ch) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.colorScheme.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.dividerColor)), child: Row(children: [Icon(Icons.hub, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(ch.name.isEmpty ? ch.channelType : ch.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))]))).toList()));
  }
}

class _CrmCommentCard extends StatefulWidget {
  final ClientModel client;
  const _CrmCommentCard({required this.client});
  @override State<_CrmCommentCard> createState() => _CrmCommentCardState();
}

class _CrmCommentCardState extends State<_CrmCommentCard> {
  late final TextEditingController _controller;
  final CrmService _crmService = CrmService();
  bool _submitting = false;

  @override void initState() { super.initState(); _controller = TextEditingController(text: widget.client.crmComment); }
  @override void didUpdateWidget(covariant _CrmCommentCard oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.client.crmComment != widget.client.crmComment) { _controller.text = widget.client.crmComment; } }
  @override void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _submitComment() async {
    final comment = _controller.text.trim();
    if (comment.isEmpty) { _showMessage('Please enter a CRM comment.'); return; }
    final accountNumber = widget.client.accNumber.trim();
    if (accountNumber.isEmpty) { _showMessage('This client does not have an ACC number.'); return; }
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final oldComment = widget.client.crmComment;
      await _crmService.submitComment(accountNumber: accountNumber, comment: comment);
      await OnboardingRepository().updateCrmComment(widget.client.id, comment);
      await OnboardingRepository().addActivity(
        clientId: widget.client.id, type: 'crm', action: 'submit_comment',
        title: 'CRM comment submitted',
        description: 'A new comment was sent to the CRM.',
        metadata: {'oldComment': oldComment, 'newComment': comment},
      );
      if (!mounted) return;
      _controller.clear();
      _showMessage('CRM comment submitted successfully.');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showMessage(e.message ?? 'Failed to submit CRM comment.', isError: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to submit CRM comment: $e', isError: true);
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : null));
  }

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.comment_outlined, color: theme.colorScheme.primary, size: 21)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n?.translate('crm_comment') ?? 'CRM Comment', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(l10n?.translate('send_crm_note') ?? 'Send a note directly to the CRM system.', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ])),
      ]),
      const SizedBox(height: 18),
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.dividerColor)), child: Row(children: [
        Icon(Icons.badge_outlined, size: 17, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text('${l10n?.translate('acc') ?? 'ACC'}:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(width: 5),
        Expanded(child: Text(widget.client.accNumber.isEmpty ? '—' : widget.client.accNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ])),
      const SizedBox(height: 14),
      TextField(controller: _controller, minLines: 5, maxLines: 8, enabled: !_submitting, decoration: InputDecoration(hintText: l10n?.translate('write_crm_comment') ?? 'Write a comment to send to CRM...', hintStyle: const TextStyle(fontSize: 13, color: Colors.grey), filled: true, fillColor: theme.colorScheme.surface, contentPadding: const EdgeInsets.all(14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.dividerColor)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.dividerColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)))),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _submitting ? null : _submitComment, style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))), icon: _submitting ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_outlined, size: 18), label: Text(_submitting ? (l10n?.translate('submitting') ?? 'Submitting...') : (l10n?.translate('submit_comment') ?? 'Submit Comment')))),
      if (widget.client.crmComment.isNotEmpty) ...[
        const SizedBox(height: 18),
        Divider(color: theme.dividerColor),
        const SizedBox(height: 12),
        Text(l10n?.translate('last_submitted_comment') ?? 'Last Submitted Comment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 7),
        Text(widget.client.crmComment, style: const TextStyle(fontSize: 13, height: 1.45)),
      ],
    ])));
  }
}

class _TimelineInfo extends StatelessWidget {
  final ClientModel client; const _TimelineInfo({required this.client});
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Section(title: l?.translate('record_info') ?? 'Timeline', icon: Icons.history, child: Row(children: [
      Expanded(child: _Row(l?.translate('created') ?? 'Created', _fDate(client.createdAt))),
      const SizedBox(width: 20),
      Expanded(child: _Row(l?.translate('last_updated') ?? 'Updated', _fDate(client.updatedAt))),
    ]));
  }
}

class _Section extends StatelessWidget {
  final String title; final IconData icon; final Widget child; final Widget? trailing;
  const _Section({required this.title, required this.icon, required this.child, this.trailing});
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 20, color: theme.colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), if (trailing != null) trailing!]),
      const SizedBox(height: 16), child,
    ])));
  }
}

class _Row extends StatelessWidget {
  final String label, value; const _Row(this.label, this.value);
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))),
      Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]));
  }
}

class _UserRow extends StatelessWidget {
  final String label, uid; final UserDisplayNameResolver r;
  const _UserRow(this.label, this.uid, this.r);
  @override Widget build(BuildContext context) {
    if (uid.isEmpty) return _Row(label, '—');
    return FutureBuilder<String>(future: r.resolve(uid), builder: (c, s) => _Row(label, s.data ?? uid));
  }
}

class _Msg extends StatelessWidget {
  final IconData icon; final String title, message;
  const _Msg({required this.icon, required this.title, required this.message});
  @override Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 50, color: Colors.grey), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(message)]));
  }
}

_SVis _statusStyle(String v) {
  final n = v.toLowerCase();
  if (n.contains('active') || n.contains('approve') || n == 'ready' || n == 'opened' || n == 'closed') return _SVis(Colors.green, Colors.green.withValues(alpha: 0.1));
  if (n.contains('progress') || n.contains('pending') || n.contains('submit')) return _SVis(Colors.orange, Colors.orange.withValues(alpha: 0.1));
  if (n.contains('fail') || n.contains('block') || n.contains('reject')) return _SVis(Colors.red, Colors.red.withValues(alpha: 0.1));
  return _SVis(Colors.grey, Colors.grey.withValues(alpha: 0.1));
}
class _SVis { final Color fg, bg; _SVis(this.fg, this.bg); }
String _fDate(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year}';
