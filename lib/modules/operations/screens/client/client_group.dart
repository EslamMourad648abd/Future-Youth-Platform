import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/client_model.dart';
import '../../repositories/onboarding_repository.dart';

class ClientGroupScreen extends StatelessWidget {
  final String clientId;

  const ClientGroupScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClientModel?>(
      stream: OnboardingRepository().watchClient(clientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null)
          return _Error(message: 'Not found.');
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
    final status = _norm(client.groupStatus);
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
                            'Group',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            client.companyName.isEmpty
                                ? 'Lifecycle'
                                : 'Lifecycle for ${client.companyName}',
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
                    _Badge(status: status),
                  ],
                ),
                const SizedBox(height: 28),
                _StatusCard(status: status),
                const SizedBox(height: 20),
                _LifecycleCard(client: client, clientId: clientId),
                const SizedBox(height: 20),
                _TimingCard(client: client),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cfg = _cfg(_norm(status));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cfg.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(cfg.icon, color: cfg.color, size: 26),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group Status',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _disp(status),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LifecycleCard extends StatefulWidget {
  final ClientModel client;
  final String clientId;

  const _LifecycleCard({required this.client, required this.clientId});

  @override
  State<_LifecycleCard> createState() => _LifecycleCardState();
}

class _LifecycleCardState extends State<_LifecycleCard> {
  String? _saving;
  static const _steps = ['not started', 'opened', 'closed'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cur = _norm(widget.client.groupStatus);
    final idx = _idx(cur);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group Lifecycle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Select a stage below.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder:
                  (c, cs) =>
                      cs.maxWidth < 650
                          ? Column(
                            children: List.generate(
                              _steps.length,
                              (i) => _step(i, idx, cur, true),
                            ),
                          )
                          : Row(
                            children: List.generate(
                              _steps.length,
                              (i) => Expanded(child: _step(i, idx, cur, false)),
                            ),
                          ),
            ),
            if (_saving != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text('Processing...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _step(int i, int curIdx, String curSt, bool v) {
    final theme = Theme.of(context);
    final st = _steps[i];
    final done = curIdx > i;
    final active = curSt == st;
    final content = InkWell(
      onTap: () => _update(st),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              active
                  ? theme.colorScheme.primary.withValues(alpha: 0.05)
                  : theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                active
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : theme.dividerColor,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    done || active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              child: Icon(
                done
                    ? Icons.check
                    : (active ? Icons.radio_button_checked : Icons.circle),
                size: done ? 18 : (active ? 17 : 9),
                color:
                    done || active
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _disp(st),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color:
                    active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
    if (v) return content;
    return Row(
      children: [
        Expanded(child: content),
        if (i < _steps.length - 1)
          Container(
            width: 30,
            height: 2,
            color: curIdx > i ? theme.colorScheme.primary : theme.dividerColor,
          ),
      ],
    );
  }

  Future<void> _update(String s) async {
    final oldStatus = widget.client.groupStatus;
    if (s == _norm(oldStatus)) return;
    if (s == 'not started') {
      final confirm = await _showConfirm(
        'Reset Group',
        'Reset to Not Started? This clears timestamps.',
      );
      if (confirm) {
        _run(() async {
          final repo = OnboardingRepository();
          await repo.updateClientFields(widget.clientId, {
            'groupStatus': 'Not Started',
            'groupOpenedAt': null,
            'groupClosedAt': null,
          });
          await repo.addActivity(
            clientId: widget.clientId,
            type: 'group',
            action: 'status_changed',
            title: 'Group status reset',
            description: 'Group status was reset to Not Started.',
            metadata: {'oldValue': oldStatus, 'newValue': 'Not Started'},
          );
        });
      }
    } else if (s == 'opened') {
      _run(() async {
        final repo = OnboardingRepository();
        await repo.updateClientFields(widget.clientId, {
          'groupStatus': 'Opened',
          'groupOpenedAt': FieldValue.serverTimestamp(),
          'groupClosedAt': null,
        });
        await repo.addActivity(
          clientId: widget.clientId,
          type: 'group',
          action: 'status_changed',
          title: 'Group opened',
          description: 'Group was opened.',
          metadata: {'oldValue': oldStatus, 'newValue': 'Opened'},
        );
      });
    } else if (s == 'closed') {
      final confirm = await _showConfirm(
        'Close Group',
        'Confirm closing the group.',
      );
      if (confirm) {
        _run(() async {
          final repo = OnboardingRepository();
          await repo.updateClientFields(widget.clientId, {
            'groupStatus': 'Closed',
            'groupClosedAt': FieldValue.serverTimestamp(),
          });
          await repo.addActivity(
            clientId: widget.clientId,
            type: 'group',
            action: 'status_changed',
            title: 'Group closed',
            description: 'Group was closed.',
            metadata: {'oldValue': oldStatus, 'newValue': 'Closed'},
          );
        });
      }
    }
  }

  void _run(Future Function() fn) async {
    setState(() => _saving = 'exec');
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<bool> _showConfirm(String t, String c) async {
    return await showDialog(
          context: context,
          builder:
              (cxt) => AlertDialog(
                title: Text(t),
                content: Text(c),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(cxt, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(cxt, true),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
        ) ??
        false;
  }
}

class _TimingCard extends StatelessWidget {
  final ClientModel client;

  const _TimingCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = _norm(client.groupStatus);
    final open = _dt(client.groupOpenedAt);
    final close = _dt(client.groupClosedAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group Timing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _Row(l: 'Opened At', v: _fDt(open)),
            _Row(l: 'Closed At', v: _fDt(close)),
            if (open != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st == 'opened' ? 'Age' : 'Duration',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          st == 'opened' ? _age(open) : _dur(open, close),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
    final c = _cfg(_norm(status)).color;
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
            _disp(status),
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

class _Error extends StatelessWidget {
  final String message;

  const _Error({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, size: 52, color: Colors.red),
          Text(message),
        ],
      ),
    );
  }
}

String _norm(String? s) {
  final n = s?.trim().toLowerCase() ?? '';
  return (n == 'not_started' || n == 'notstarted')
      ? 'not started'
      : (n == 'open' ? 'opened' : n);
}

String _disp(String? s) {
  final n = _norm(s);
  return n[0].toUpperCase() + n.substring(1);
}

int _idx(String s) {
  switch (s) {
    case 'not started':
      return 0;
    case 'opened':
      return 1;
    case 'closed':
      return 2;
    default:
      return 0;
  }
}

class _Cfg {
  final Color color;
  final IconData icon;

  const _Cfg(this.color, this.icon);
}

_Cfg _cfg(String s) {
  switch (s) {
    case 'opened':
      return const _Cfg(Colors.blue, Icons.folder_open);
    case 'closed':
      return const _Cfg(Colors.green, Icons.folder);
    default:
      return const _Cfg(Colors.grey, Icons.folder_outlined);
  }
}

DateTime? _dt(dynamic v) =>
    v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

String _fDt(DateTime? d) =>
    d == null
        ? '—'
        : '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

String _age(DateTime o) {
  final d = DateTime.now().difference(o);
  return _fDur(d);
}

String _dur(DateTime o, DateTime? c) =>
    c == null ? '—' : _fDur(c.difference(o));

String _fDur(Duration d) {
  final m = d.inMinutes;
  final days = m ~/ (60 * 24), h = (m % (60 * 24)) ~/ 60, rm = m % 60;
  if (days > 0) return '$days d $h h';
  if (h > 0) return '$h h $rm m';
  return '$rm min';
}
