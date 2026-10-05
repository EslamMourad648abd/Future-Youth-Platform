import 'package:flutter/material.dart';

import '../../models/client_model.dart';
import '../../repositories/onboarding_repository.dart';

class ClientActivationScreen extends StatelessWidget {
  final String clientId;

  const ClientActivationScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClientModel?>(
      stream: OnboardingRepository().watchClient(clientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null)
          return _Error(message: 'Client not found.');
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
    final status = _norm(client.activationStatus);
    return SingleChildScrollView(
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
                          'Activation',
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
                  _Badge(status: client.activationStatus),
                ],
              ),
              const SizedBox(height: 28),
              _StatusCard(status: client.activationStatus),
              const SizedBox(height: 20),
              _ProgressCard(status: status, clientId: clientId),
              const SizedBox(height: 20),
              if (_isExc(status)) ...[
                const SizedBox(height: 20),
                _ExcCard(clientId: clientId, currentStatus: status),
              ],
            ],
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
                  'Activation Status',
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

class _ProgressCard extends StatefulWidget {
  final String status, clientId;

  const _ProgressCard({required this.status, required this.clientId});

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard> {
  String? _saving;
  static const _steps = ['Req Not Complete', 'in progress', 'pending', 'activated'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cur = _norm(widget.status);
    final idx = _idx(cur);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activation Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Update stages here.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder:
                  (c, cs) =>
                      cs.maxWidth < 700
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
                    Text('Updating...'),
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
    if (s == _norm(widget.status)) return;
    final oldSt = widget.status;
    setState(() => _saving = s);
    try {
      final repo = OnboardingRepository();
      await repo.updateStatuses(clientId: widget.clientId, activationStatus: s);
      await repo.addActivity(
        clientId: widget.clientId,
        type: 'activation',
        action: 'status_changed',
        title: 'Activation status changed',
        description:
            'Activation status changed from "${_disp(oldSt)}" to "${_disp(s)}".',
        metadata: {
          'field': 'activationStatus',
          'oldValue': oldSt,
          'newValue': s,
        },
      );
    } finally {
      if (mounted) setState(() => _saving = null);
    }
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
    final theme = Theme.of(context);
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

class _ExcCard extends StatelessWidget {
  final String clientId, currentStatus;

  const _ExcCard({required this.clientId, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.red, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                const Text(
                  'Activation Exception',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Underlying issues must be resolved.'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    () => OnboardingRepository().updateStatuses(
                      clientId: clientId,
                      activationStatus: 'in progress',
                    ),
                child: const Text('Return to In Progress'),
              ),
            ),
          ],
        ),
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
  return n == 'Req Not Complete' || n == 'reqnotcomplete'
      ? 'Req Not Complete'
      : (n == 'in_progress' || n == 'inprogress'
          ? 'in progress'
          : (n == 'active' ? 'activated' : n));
}

String _disp(String? s) {
  final n = _norm(s);
  return n[0].toUpperCase() + n.substring(1);
}

bool _isExc(String s) => ['failed', 'blocked', 'rejected'].contains(s);

int _idx(String s) {
  switch (s) {
    case 'Req Not Complete':
      return 0;
    case 'in progress':
      return 1;
    case 'pending':
      return 2;
    case 'activated':
      return 3;
    default:
      return 1;
  }
}

class _Cfg {
  final Color color;
  final IconData icon;

  const _Cfg(this.color, this.icon);
}

_Cfg _cfg(String s) {
  switch (s) {
    case 'activated':
    case 'active':
      return const _Cfg(Colors.green, Icons.check_circle);
    case 'failed':
    case 'blocked':
    case 'rejected':
      return const _Cfg(Colors.red, Icons.error);
    case 'pending':
      return const _Cfg(Colors.orange, Icons.pending);
    case 'in progress':
      return const _Cfg(Colors.blue, Icons.sync);
    default:
      return const _Cfg(Colors.grey, Icons.radio_button_unchecked);
  }
}
