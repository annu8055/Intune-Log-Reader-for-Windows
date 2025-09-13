import 'package:flutter/material.dart';

enum LogLevel {
  error('ERROR'),
  warning('WARNING'),
  info('INFO'),
  debug('DEBUG');

  const LogLevel(this.value);
  final String value;

  Color get color {
    switch (this) {
      case LogLevel.error:
        return Colors.red;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.debug:
        return Colors.grey;
    }
  }
}

class LogEntry {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final String component;
  final String message;
  final String fullText;
  final LogCategory? category;

  LogEntry({
    String? id,
    required this.timestamp,
    required this.level,
    required this.component,
    required this.message,
    required this.fullText,
    this.category,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum LogCategory {
  dashboard('Dashboard', Icons.dashboard, Colors.blue),
  devices('Device', Icons.computer, Colors.green),
  applications('Applications', Icons.apps, Colors.purple),
  configurations('Configurations', Icons.settings, Colors.orange),
  compliance('Compliance', Icons.verified_user, Colors.red),
  syncStatus('Sync Status', Icons.sync, Colors.cyan),
  logs('Logs', Icons.description, Colors.grey);

  const LogCategory(this.displayName, this.icon, this.color);
  
  final String displayName;
  final IconData icon;
  final Color color;
}
