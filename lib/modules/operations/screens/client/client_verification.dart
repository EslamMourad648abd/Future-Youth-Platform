import 'package:flutter/material.dart';

import '../../models/client_model.dart';
import '../../repositories/onboarding_repository.dart';

class ClientVerificationScreen extends StatelessWidget {
  final String clientId;

  const ClientVerificationScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClientModel?>(
      stream: OnboardingRepository().watchClient(clientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null)
          return _Msg(
            icon: Icons.error_outline,
            title: 'Error',
            message: 'Not found.',
          );
        return _Content(client: snapshot.data!, clientId: clientId);
      },
    );
  }
}

class _Content extends StatelessWidget {
  final ClientModel client;
  final String clientId;

  const _Content({required this.client, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ck = _normCk(client.verificationChecklist);
    final prog = _Prog.fromCk(ck);
    final st = _normSt(client.verificationStatus);

    return Container(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verification',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            client.companyName.isEmpty
                                ? 'Workflow'
                                : 'Workflow for ${client.companyName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Badge(status: st),
                  ],
                ),
                const SizedBox(height: 28),
                _SummaryCard(status: st, progress: prog),
                const SizedBox(height: 20),
                _ChecklistCard(
                  clientId: clientId,
                  accountNumber: client.accNumber,
                  checklist: ck,
                  status: st,
                ),
                if (st == 'rejected') ...[
                  const SizedBox(height: 20),
                  _RejCard(
                    clientId: clientId,
                    accountNumber: client.accNumber,
                    checklist: ck,
                  ),
                ],
                const SizedBox(height: 20),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String status;
  final _Prog progress;

  const _SummaryCard({required this.status, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cfg = _cfg(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (c, cs) {
            final isComp = cs.maxWidth < 650;
            final stPart = Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(cfg.icon, color: cfg.color, size: 27),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _dispSt(status),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            );
            final prPart = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Checklist Progress',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${progress.perc}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress.ratio,
                    minHeight: 9,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${progress.comp} / ${progress.total} completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            );
            if (isComp)
              return Column(
                children: [stPart, const Divider(height: 40), prPart],
              );
            return Row(
              children: [
                Expanded(child: stPart),
                Container(
                  width: 1,
                  height: 70,
                  color: theme.dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                ),
                Expanded(child: prPart),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatefulWidget {
  final String clientId, accountNumber, status;
  final Map<String, bool> checklist;

  const _ChecklistCard({
    required this.clientId,
    required this.accountNumber,
    required this.checklist,
    required this.status,
  });

  @override
  State<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<_ChecklistCard> {
  String? _saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.fact_check_outlined,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification Checklist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Complete requirements manually.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...List.generate(
              def.length,
              (i) => _Item(
                num: i + 1,
                def: def[i],
                checked: widget.checklist[def[i].key] ?? false,
                saving: _saving == def[i].key,
                disabled: _saving != null,
                onTap: () => _toggle(def[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(_Def d) async {
    if (_saving != null) return;
    final prevCk = Map<String, bool>.from(widget.checklist);
    final up = Map<String, bool>.from(widget.checklist);
    up[d.key] = !(up[d.key] ?? false);

    if (d.key == 'verificationSubmitted' && up['verificationSubmitted'] != true)
      up['verificationApproved'] = false;
    if (d.key == 'verificationApproved' && up['verificationApproved'] == true)
      up['verificationSubmitted'] = true;

    final ns = _derive(up);
    final changed = <String, Map<String, dynamic>>{};
    for (var it in def) {
      final oldV = prevCk[it.key] ?? false, newV = up[it.key] ?? false;
      if (oldV != newV)
        changed[it.key] = {
          'oldValue': oldV,
          'newValue': newV,
          'title': it.title,
        };
    }

    setState(() => _saving = d.key);
    try {
      final repo = OnboardingRepository();
      await repo.updateVerificationChecklist(
        clientId: widget.clientId,
        checklist: up,
        verificationStatus: ns,
      );
      await repo.updateVerificationStatusInZoho(
        accountNumber: widget.accountNumber,
        verificationStatus: ns,
      );
      await repo.addActivity(
        clientId: widget.clientId,
        type: 'verification_updated',
        action: 'update_verification',
        title: 'Verification checklist updated',
        description:
            '${d.title} was ${up[d.key] == true ? 'completed' : 'marked incomplete'}.',
        metadata: {
          'changedItem': d.key,
          'changedItemTitle': d.title,
          'oldValue': prevCk[d.key] ?? false,
          'newValue': up[d.key] ?? false,
          'previousStatus': widget.status,
          'newStatus': ns,
          'changedChecklist': changed,
        },
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${d.title} updated.'),
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification saved, but CRM sync failed: $e'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }
}

class _Item extends StatelessWidget {
  final int num;
  final _Def def;
  final bool checked, saving, disabled;
  final VoidCallback onTap;

  const _Item({
    required this.num,
    required this.def,
    required this.checked,
    required this.saving,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color:
                checked
                    ? Colors.green.withValues(alpha: 0.05)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color:
                  checked
                      ? Colors.green.withValues(alpha: 0.2)
                      : theme.dividerColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? Colors.green : Colors.transparent,
                  border: Border.all(
                    color:
                        checked
                            ? Colors.green
                            : theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                    width: 2,
                  ),
                ),
                child:
                    saving
                        ? const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : (checked
                            ? const Icon(
                              Icons.check,
                              size: 17,
                              color: Colors.white,
                            )
                            : Center(
                              child: Text(
                                '$num',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            )),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: checked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      def.desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _Row extends StatelessWidget {
  final String l, v;

  const _Row({required this.l, required this.v});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              l,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '—' : v,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String status;

  const _Badge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = _cfg(_normSt(status)).color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: c),
          const SizedBox(width: 7),
          Text(
            _dispSt(status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _RejCard extends StatefulWidget {
  final String clientId, accountNumber;
  final Map<String, bool> checklist;

  const _RejCard({
    required this.clientId,
    required this.accountNumber,
    required this.checklist,
  });

  @override
  State<_RejCard> createState() => _RejCardState();
}

class _RejCardState extends State<_RejCard> {
  bool _saving = false;

  Future<void> _restore() async {
    if (_saving) return;
    final ns = _derive(widget.checklist);
    setState(() => _saving = true);
    try {
      final repo = OnboardingRepository();
      await repo.updateStatuses(
        clientId: widget.clientId,
        verificationStatus: ns,
      );
      await repo.updateVerificationStatusInZoho(
        accountNumber: widget.accountNumber,
        verificationStatus: ns,
      );
      await repo.addActivity(
        clientId: widget.clientId,
        type: 'verification_status_changed',
        action: 'restore_verification',
        title: 'Verification restored',
        description:
            'Verification was returned from Rejected to ${_dispSt(ns)}.',
        metadata: {
          'previousStatus': 'rejected',
          'newStatus': ns,
          'reason': 'continue_verification',
        },
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification returned to ${_dispSt(ns)}.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification restored, but CRM sync failed: $e'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.red),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.cancel, color: Colors.red),
                SizedBox(width: 12),
                Text(
                  'Verification Rejected',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Please resolve issues before continuing.'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saving ? null : _restore,
                child:
                    _saving
                        ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Continue Verification'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Msg extends StatelessWidget {
  final IconData icon;
  final String title, message;

  const _Msg({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Colors.grey),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(message),
        ],
      ),
    );
  }
}

String _normSt(String? s) {
  final n = s?.trim().toLowerCase() ?? '';
  if (n == 'not_started' || n == 'notstarted') return 'not started';
  if (n == 'in_progress' || n == 'inprogress') return 'in progress';
  if (n == 'verified') return 'approved';
  return n;
}

String _dispSt(String? s) {
  final n = _normSt(s);
  return n[0].toUpperCase() + n.substring(1);
}

String _derive(Map<String, bool> ck) {
  if (ck['verificationApproved'] == true) return 'approved';
  if (ck['verificationSubmitted'] == true) return 'submitted';
  return ck.values.any((v) => v) ? 'in progress' : 'not started';
}

Map<String, bool> _normCk(Map<String, bool> src) {
  return {for (var d in def) d.key: src[d.key] ?? false};
}

class _Def {
  final String key, title, desc;
  final IconData icon;

  const _Def({
    required this.key,
    required this.title,
    required this.desc,
    required this.icon,
  });
}

const def = [
  _Def(
    key: 'businessInfo',
    title: 'Business Info',
    desc: 'Collected and added.',
    icon: Icons.business,
  ),
  _Def(
    key: 'websiteReady',
    title: 'Website Ready',
    desc: 'Client site is live.',
    icon: Icons.language,
  ),
  _Def(
    key: 'aboutUs',
    title: 'About Us',
    desc: 'Info added to site.',
    icon: Icons.info,
  ),
  _Def(
    key: 'businessNameMatchesCr',
    title: 'Name Matches CR',
    desc: 'Display name is correct.',
    icon: Icons.badge,
  ),
  _Def(
    key: 'metaTag',
    title: 'Meta Tag',
    desc: 'Tag added to site.',
    icon: Icons.code,
  ),
  _Def(
    key: 'domainVerified',
    title: 'Domain Verified',
    desc: 'Domain check complete.',
    icon: Icons.domain_verification,
  ),
  _Def(
    key: 'documentsUploaded',
    title: 'Docs Uploaded',
    desc: 'Verification docs sent.',
    icon: Icons.upload_file,
  ),
  _Def(
    key: 'verificationSubmitted',
    title: 'Submitted to Meta',
    desc: 'Sent to Meta.',
    icon: Icons.send,
  ),
  _Def(
    key: 'verificationApproved',
    title: 'Meta Approved',
    desc: 'Approval received.',
    icon: Icons.verified,
  ),
];

class _Prog {
  final int comp, total;

  _Prog(this.comp, this.total);

  double get ratio => total == 0 ? 0 : comp / total;

  int get perc => (ratio * 100).round();

  factory _Prog.fromCk(Map<String, bool> ck) {
    return _Prog(ck.values.where((v) => v).length, def.length);
  }
}

class _Cfg {
  final Color color;
  final IconData icon;

  const _Cfg(this.color, this.icon);
}

_Cfg _cfg(String s) {
  switch (s) {
    case 'verified':
      return const _Cfg(Colors.green, Icons.verified);
    case 'in review':
      return const _Cfg(Colors.orange, Icons.send);
    case 'in progress':
      return const _Cfg(Colors.blue, Icons.sync);
    case 'rejected':
      return const _Cfg(Colors.red, Icons.cancel);
    default:
      return const _Cfg(Colors.grey, Icons.radio_button_unchecked);
  }
}
