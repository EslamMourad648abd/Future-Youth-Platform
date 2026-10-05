import 'package:flutter/material.dart';
import '../../services/debug_log_service.dart';

class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logService = DebugLogService();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: const Text(
          'System logs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear logs',
            onPressed: () => logService.clear(),
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ValueListenableBuilder<List<LogEntry>>(
        valueListenable: logService.logsNotifier,
        builder: (context, logs, _) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.terminal_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No logs yet.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: logs.length,
            reverse: true, // Show latest logs at the top
            itemBuilder: (context, index) {
              final log = logs[logs.length - 1 - index];
              return _LogItem(log: log);
            },
          );
        },
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final LogEntry log;
  const _LogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getLogColor(log.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              log.timeFormatted,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      log.userName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Spacer(),
                    Text(
                      _getPrefix(log.level),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  log.message,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: color.withValues(alpha: 0.9),
                    fontWeight: log.level == LogLevel.error ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.info: return 'INFO';
      case LogLevel.success: return 'SUCCESS';
      case LogLevel.warning: return 'WARNING';
      case LogLevel.error: return 'ERROR';
      case LogLevel.ui: return 'ACTION';
    }
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info: return Colors.blueGrey;
      case LogLevel.success: return Colors.green;
      case LogLevel.warning: return Colors.orange;
      case LogLevel.error: return Colors.red;
      case LogLevel.ui: return Colors.indigo;
    }
  }
}
