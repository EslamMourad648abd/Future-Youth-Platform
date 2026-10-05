import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum LogLevel { info, success, warning, error, ui }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final String userName;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.userName,
    this.level = LogLevel.info,
  });

  String get timeFormatted =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
}

class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  final ValueNotifier<List<LogEntry>> logsNotifier = ValueNotifier([]);

  void log(String message, {LogLevel level = LogLevel.info}) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email ?? 'System';

    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      userName: userName,
      level: level,
    );

    // Keep only the last 1000 logs to prevent memory leaks
    final currentLogs = List<LogEntry>.from(logsNotifier.value);
    if (currentLogs.length >= 1000) {
      currentLogs.removeAt(0);
    }
    currentLogs.add(entry);
    logsNotifier.value = currentLogs;

    // Also print to system console
    final prefix = _getPrefix(level);
    debugPrint('$prefix $message');
  }

  void info(String m) => log(m, level: LogLevel.info);
  void success(String m) => log(m, level: LogLevel.success);
  void warning(String m) => log(m, level: LogLevel.warning);
  void error(String m) => log(m, level: LogLevel.error);
  void ui(String m) => log(m, level: LogLevel.ui);

  void clear() {
    logsNotifier.value = [];
  }

  String _getPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.info: return 'ℹ️ [INFO]';
      case LogLevel.success: return '✅ [SUCCESS]';
      case LogLevel.warning: return '⚠️ [WARNING]';
      case LogLevel.error: return '❌ [ERROR]';
      case LogLevel.ui: return '➡️ [UI]';
    }
  }
}
