import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';
import 'log_categorization_service.dart';

class LogFileService extends ChangeNotifier {
  List<LogEntry> _entries = [];
  int _errorCount = 0;
  int _warningCount = 0;
  int _totalCount = 0;
  bool _isMonitoring = false;
  String? _currentPath;
  final LogCategorizationService _categorizationService = LogCategorizationService();

  List<LogEntry> get entries => _entries;
  int get errorCount => _errorCount;
  int get warningCount => _warningCount;
  int get totalCount => _totalCount;
  bool get isMonitoring => _isMonitoring;
  LogCategorizationService get categorizationService => _categorizationService;

  Future<void> loadLogFile(String path) async {
    try {
      _currentPath = path;
      _entries.clear();

      final file = File(path);
      if (!await file.exists()) {
        throw Exception('File not found: $path');
      }

      final content = await file.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

      for (String line in lines) {
        final entry = _parseWindowsIntuneLogLine(line);
        if (entry != null) {
          _entries.add(entry);
        }
      }

      _updateCounts();
      _categorizationService.categorizeLogs(_entries);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading log file: $e');
    }
  }

  LogEntry? _parseWindowsIntuneLogLine(String line) {
    // Format: <![LOG[message]LOG]!><time="HH:mm:ss.fffffff" date="M-d-yyyy" component="ComponentName" context="" type="1" thread="X" file="">
    
    try {
      // Extract message
      final logStart = line.indexOf('<![LOG[');
      final logEnd = line.indexOf(']LOG]!>');
      if (logStart == -1 || logEnd == -1) return null;

      final message = line.substring(logStart + 7, logEnd);

      // Extract attributes
      final attributesStart = logEnd + 7; // After ']LOG]!>'
      final attributesSection = line.substring(attributesStart);

      // Parse time
      final timeMatch = RegExp(r'time="([^"]*)"').firstMatch(attributesSection);
      final timeStr = timeMatch?.group(1);

      // Parse date
      final dateMatch = RegExp(r'date="([^"]*)"').firstMatch(attributesSection);
      final dateStr = dateMatch?.group(1);

      // Parse component
      final componentMatch = RegExp(r'component="([^"]*)"').firstMatch(attributesSection);
      final component = componentMatch?.group(1) ?? 'Unknown';

      // Parse type (log level)
      final typeMatch = RegExp(r'type="([^"]*)"').firstMatch(attributesSection);
      final typeStr = typeMatch?.group(1) ?? '1';

      // Parse thread
      final threadMatch = RegExp(r'thread="([^"]*)"').firstMatch(attributesSection);
      final threadStr = threadMatch?.group(1) ?? '0';

      if (timeStr == null || dateStr == null) return null;

      // Parse timestamp
      final timestamp = _parseWindowsTimestamp(dateStr, timeStr);
      if (timestamp == null) return null;

      // Map log level
      LogLevel level;
      switch (typeStr) {
        case '3':
          level = LogLevel.error;
          break;
        case '2':
          level = LogLevel.warning;
          break;
        case '1':
          level = LogLevel.info;
          break;
        case '4':
          level = LogLevel.debug;
          break;
        default:
          level = LogLevel.info;
      }

      return LogEntry(
        timestamp: timestamp,
        level: level,
        component: '$component (Thread $threadStr)',
        message: message,
        fullText: line,
      );
    } catch (e) {
      debugPrint('Error parsing Windows Intune log line: $e');
      return null;
    }
  }

  DateTime? _parseWindowsTimestamp(String dateStr, String timeStr) {
    try {
      // Date format: M-d-yyyy (e.g., "9-13-2025")
      // Time format: HH:mm:ss.fffffff (e.g., "22:48:21.3523272")

      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) return null;

      final timeParts = timeStr.split(':');
      if (timeParts.length != 3) return null;

      final secondsParts = timeParts[2].split('.');
      
      final month = int.parse(dateParts[0]);
      final day = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);
      
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = int.parse(secondsParts[0]);
      
      // Handle microseconds (Windows uses 7-digit precision, Dart uses 6)
      int microsecond = 0;
      if (secondsParts.length > 1) {
        String microStr = secondsParts[1].padRight(6, '0').substring(0, 6);
        microsecond = int.parse(microStr);
      }

      return DateTime(year, month, day, hour, minute, second, 0, microsecond);
    } catch (e) {
      debugPrint('Error parsing Windows timestamp: $e');
      return null;
    }
  }

  void _updateCounts() {
    _totalCount = _entries.length;
    _errorCount = _entries.where((entry) => entry.level == LogLevel.error).length;
    _warningCount = _entries.where((entry) => entry.level == LogLevel.warning).length;
  }

  List<MapEntry<String, int>> detectErrorPatterns({int limit = 5}) {
    final errors = _entries.where((entry) => entry.level == LogLevel.error);
    final Map<String, int> patterns = {};

    for (final error in errors) {
      final message = error.message;
      
      // Extract error codes or patterns
      String pattern;
      final hexMatch = RegExp(r'0x[0-9A-Fa-f]{8}').firstMatch(message);
      if (hexMatch != null) {
        pattern = hexMatch.group(0)!;
      } else {
        final errorMatch = RegExp(r'Error:\s*([^,]+)').firstMatch(message);
        if (errorMatch != null) {
          pattern = errorMatch.group(1)!;
        } else {
          // Use first 50 characters as pattern
          pattern = message.length > 50 ? message.substring(0, 50) : message;
        }
      }

      patterns[pattern] = (patterns[pattern] ?? 0) + 1;
    }

    final sortedPatterns = patterns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPatterns.take(limit).toList();
  }

  Future<void> loadAllIntuneLogFiles() async {
    const logPath = r'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs';
    try {
      final directory = Directory(logPath);
      if (!await directory.exists()) {
        throw Exception('Intune logs directory not found: $logPath');
      }

      _entries.clear();
      
      final files = await directory.list()
          .where((entity) => entity is File && entity.path.endsWith('.log'))
          .cast<File>()
          .toList();

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

          for (String line in lines) {
            final entry = _parseWindowsIntuneLogLine(line);
            if (entry != null) {
              _entries.add(entry);
            }
          }
        } catch (e) {
          debugPrint('Error reading ${file.path}: $e');
        }
      }

      // Sort entries by timestamp
      _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      _updateCounts();
      _categorizationService.categorizeLogs(_entries);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading Intune log files: $e');
    }
  }

  void clearLogs() {
    _entries.clear();
    _updateCounts();
    notifyListeners();
  }
}
