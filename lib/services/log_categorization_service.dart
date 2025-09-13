import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';

class LogCategorizationService extends ChangeNotifier {
  Map<LogCategory, List<LogEntry>> _categorizedLogs = {};
  Map<LogCategory, CategoryStats> _categoryStats = {};

  Map<LogCategory, List<LogEntry>> get categorizedLogs => _categorizedLogs;
  Map<LogCategory, CategoryStats> get categoryStats => _categoryStats;

  void categorizeLogs(List<LogEntry> entries) {
    _categorizedLogs = {};
    
    // Initialize all categories
    for (final category in LogCategory.values) {
      _categorizedLogs[category] = [];
    }

    // Categorize each log entry
    for (final entry in entries) {
      final category = _determineCategory(entry);
      _categorizedLogs[category]?.add(entry);
    }

    _updateCategoryStats();
    notifyListeners();
  }

  LogCategory _determineCategory(LogEntry entry) {
    final message = entry.message.toLowerCase();
    final component = entry.component.toLowerCase();

    // Device-related logs
    if (_containsAny(message, ['device', 'enrollment', 'registration', 'mdm certificate']) ||
        _containsAny(component, ['device', 'enrollment'])) {
      return LogCategory.devices;
    }

    // Application-related logs
    if (_containsAny(message, ['app', 'application', 'install', 'uninstall', 'deployment', 'win32app']) ||
        _containsAny(component, ['app', 'application', 'win32app'])) {
      return LogCategory.applications;
    }

    // Configuration-related logs
    if (_containsAny(message, ['config', 'configuration', 'policy', 'setting', 'profile']) ||
        _containsAny(component, ['config', 'policy'])) {
      return LogCategory.configurations;
    }

    // Compliance-related logs
    if (_containsAny(message, ['compliance', 'violation', 'remediation', 'non-compliant', 'compliant']) ||
        _containsAny(component, ['compliance'])) {
      return LogCategory.compliance;
    }

    // Sync-related logs
    if (_containsAny(message, ['sync', 'synchronization', 'upload', 'download', 'checkin', 'check-in']) ||
        _containsAny(component, ['sync', 'upload', 'download'])) {
      return LogCategory.syncStatus;
    }

    // Dashboard/General logs
    if (_containsAny(message, ['dashboard', 'summary', 'overview', 'status']) ||
        _containsAny(component, ['dashboard', 'summary'])) {
      return LogCategory.dashboard;
    }

    // Default to logs category
    return LogCategory.logs;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  void _updateCategoryStats() {
    _categoryStats = {};
    
    for (final entry in _categorizedLogs.entries) {
      final category = entry.key;
      final logs = entry.value;
      
      final errorCount = logs.where((log) => log.level == LogLevel.error).length;
      final warningCount = logs.where((log) => log.level == LogLevel.warning).length;
      final infoCount = logs.where((log) => log.level == LogLevel.info).length;
      final debugCount = logs.where((log) => log.level == LogLevel.debug).length;
      
      _categoryStats[category] = CategoryStats(
        totalCount: logs.length,
        errorCount: errorCount,
        warningCount: warningCount,
        infoCount: infoCount,
        debugCount: debugCount,
      );
    }
  }

  List<LogEntry> getLogsForCategory(LogCategory category) {
    return _categorizedLogs[category] ?? [];
  }

  CategoryStats? getStatsForCategory(LogCategory category) {
    return _categoryStats[category];
  }

  List<ErrorPattern> getTopErrors(LogCategory category, {int limit = 5}) {
    final entries = getLogsForCategory(category);
    final errors = entries.where((entry) => entry.level == LogLevel.error);
    
    final patterns = <String, int>{};
    for (final error in errors) {
      final pattern = _extractErrorPattern(error.message);
      patterns[pattern] = (patterns[pattern] ?? 0) + 1;
    }
    
    return patterns.entries
        .map((e) => ErrorPattern(pattern: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count))
      ..take(limit);
  }

  String _extractErrorPattern(String message) {
    // Extract hex codes
    final hexMatch = RegExp(r'0x[0-9A-Fa-f]{8}').firstMatch(message);
    if (hexMatch != null) return hexMatch.group(0)!;
    
    // Extract error messages
    final errorMatch = RegExp(r'Error:\s*([^,]+)').firstMatch(message);
    if (errorMatch != null) return errorMatch.group(1)!;
    
    // Extract failed operations
    final failMatch = RegExp(r'Failed to ([^,\.]+)').firstMatch(message);
    if (failMatch != null) return 'Failed to ${failMatch.group(1)!}';
    
    // Use first 50 characters
    return message.length > 50 ? message.substring(0, 50) : message;
  }

  List<LogEntry> getRecentActivity(LogCategory category, {int hours = 1}) {
    final entries = getLogsForCategory(category);
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    
    return entries
        .where((entry) => entry.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}

class CategoryStats {
  final int totalCount;
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final int debugCount;

  const CategoryStats({
    required this.totalCount,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    required this.debugCount,
  });

  double get errorRate => totalCount > 0 ? (errorCount / totalCount) * 100 : 0.0;
  double get warningRate => totalCount > 0 ? (warningCount / totalCount) * 100 : 0.0;
}

class ErrorPattern {
  final String pattern;
  final int count;

  const ErrorPattern({required this.pattern, required this.count});
}
