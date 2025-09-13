import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/log_file_service.dart';
import 'models/log_entry.dart';
import 'views/category_view.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() {
  runApp(const IntuneLogReaderApp());
}

class IntuneLogReaderApp extends StatelessWidget {
  const IntuneLogReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LogFileService(),
      child: MaterialApp(
        title: 'Intune Log Reader',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainView(),
      ),
    );
  }
}

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  LogCategory _selectedCategory = LogCategory.dashboard;

  @override
  Widget build(BuildContext context) {
    return Consumer<LogFileService>(
      builder: (context, logService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Intune Log Reader - Windows'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              IconButton(
                onPressed: () => _loadAllIntuneLogs(context),
                icon: const Icon(Icons.refresh),
                tooltip: 'Load All Intune Logs',
              ),
              IconButton(
                onPressed: () => _loadSingleLogFile(context),
                icon: const Icon(Icons.folder_open),
                tooltip: 'Load Single Log File',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.save_alt),
                tooltip: 'Export',
                onSelected: (value) => _handleExport(context, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'csv', child: Text('Export All (CSV)')),
                  const PopupMenuItem(value: 'errors', child: Text('Export Errors Only (CSV)')),
                  const PopupMenuItem(value: 'report', child: Text('Export Detailed Report')),
                ],
              ),
              if (logService.entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Text(
                      '${logService.totalCount} entries | ${logService.errorCount} errors',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          body: Row(
            children: [
              // Enhanced sidebar
              NavigationSidebar(
                logService: logService,
                selectedCategory: _selectedCategory,
                onCategorySelected: (category) {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              ),
              const VerticalDivider(thickness: 1, width: 1),
              // Main content
              Expanded(
                child: _buildContentView(logService),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentView(LogFileService logService) {
    if (logService.entries.isEmpty) {
      return _buildWelcomeView();
    }

    switch (_selectedCategory) {
      case LogCategory.dashboard:
        return DashboardContentView(logService: logService);
      default:
        return CategoryView(category: _selectedCategory, logService: logService);
    }
  }

  Widget _buildWelcomeView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Intune Log Reader for Windows',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Professional Intune log analysis and monitoring'),
          const SizedBox(height: 32),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _loadAllIntuneLogs(context),
                icon: const Icon(Icons.refresh),
                label: const Text('Load All Intune Logs'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _loadSingleLogFile(context),
                icon: const Icon(Icons.folder_open),
                label: const Text('Browse for Log File'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadAllIntuneLogs(BuildContext context) async {
    final logService = Provider.of<LogFileService>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading Intune logs...'),
          ],
        ),
      ),
    );

    await logService.loadAllIntuneLogFiles();
    
    if (context.mounted) {
      Navigator.of(context).pop();
      
      if (logService.totalCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${logService.totalCount} log entries from all Intune logs'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Intune logs found or accessible'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadSingleLogFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['log', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      final logService = Provider.of<LogFileService>(context, listen: false);
      await logService.loadLogFile(result.files.single.path!);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded ${logService.totalCount} log entries')),
        );
      }
    }
  }

  void _handleExport(BuildContext context, String type) async {
    final logService = Provider.of<LogFileService>(context, listen: false);
    
    switch (type) {
      case 'csv':
        await _exportToCSV(context, logService.entries, 'intune_logs');
        break;
      case 'errors':
        final errors = logService.entries.where((e) => e.level == LogLevel.error).toList();
        await _exportToCSV(context, errors, 'intune_errors');
        break;
      case 'report':
        await _exportDetailedReport(context, logService);
        break;
    }
  }

  Future<void> _exportToCSV(BuildContext context, List<LogEntry> logs, String prefix) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export CSV',
      fileName: '${prefix}_${DateTime.now().millisecondsSinceEpoch}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      final csv = _generateCSV(logs);
      await File(result).writeAsString(csv);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV exported successfully')),
        );
      }
    }
  }

  Future<void> _exportDetailedReport(BuildContext context, LogFileService logService) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Report',
      fileName: 'intune_report_${DateTime.now().millisecondsSinceEpoch}.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null) {
      final report = _generateDetailedReport(logService);
      await File(result).writeAsString(report);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported successfully')),
        );
      }
    }
  }

  String _generateCSV(List<LogEntry> logs) {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Level,Component,Message');
    
    for (final log in logs) {
      final timestamp = log.timestamp.toIso8601String();
      final level = log.level.value;
      final component = '"${log.component.replaceAll('"', '""')}"';
      final message = '"${log.message.replaceAll('"', '""')}"';
      buffer.writeln('$timestamp,$level,$component,$message');
    }
    
    return buffer.toString();
  }

  String _generateDetailedReport(LogFileService logService) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    
    buffer.writeln('INTUNE LOG ANALYSIS REPORT');
    buffer.writeln('Generated: ${now.toString()}');
    buffer.writeln('');
    
    buffer.writeln('========== SUMMARY ==========');
    buffer.writeln('Total Entries: ${logService.totalCount}');
    buffer.writeln('Errors: ${logService.errorCount}');
    buffer.writeln('Warnings: ${logService.warningCount}');
    buffer.writeln('');
    
    // Category breakdown
    buffer.writeln('========== CATEGORY BREAKDOWN ==========');
    for (final category in LogCategory.values) {
      final stats = logService.categorizationService.getStatsForCategory(category);
      if (stats != null && stats.totalCount > 0) {
        buffer.writeln('${category.displayName}: ${stats.totalCount} entries (${stats.errorCount} errors, ${stats.warningCount} warnings)');
      }
    }
    buffer.writeln('');
    
    // Top error patterns
    buffer.writeln('========== TOP ERROR PATTERNS ==========');
    final errorPatterns = logService.detectErrorPatterns();
    for (final pattern in errorPatterns) {
      buffer.writeln('- ${pattern.key}: ${pattern.value} occurrences');
    }
    buffer.writeln('');
    
    // Recent errors
    buffer.writeln('========== RECENT ERRORS ==========');
    final errors = logService.entries
        .where((e) => e.level == LogLevel.error)
        .take(20)
        .toList();
    
    for (final error in errors) {
      buffer.writeln('${error.timestamp} | ${error.component} | ${error.message}');
    }
    
    return buffer.toString();
  }
}

// Enhanced Navigation Sidebar
class NavigationSidebar extends StatelessWidget {
  final LogFileService logService;
  final LogCategory selectedCategory;
  final Function(LogCategory) onCategorySelected;

  const NavigationSidebar({
    super.key,
    required this.logService,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Colors.grey[50],
      child: Column(
        children: [
          // File info section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log Category',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  logService.entries.isEmpty 
                      ? 'No files loaded'
                      : '${logService.totalCount} entries loaded',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (logService.isMonitoring) ...[
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.radio_button_checked, color: Colors.green, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Live monitoring',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Navigation categories
          Expanded(
            child: ListView.builder(
              itemCount: LogCategory.values.length,
              itemBuilder: (context, index) {
                final category = LogCategory.values[index];
                final stats = logService.categorizationService.getStatsForCategory(category);
                final isSelected = selectedCategory == category;
                
                return InkWell(
                  onTap: () => onCategorySelected(category),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                      border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(category.icon, color: category.color, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.displayName,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (stats != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${stats.totalCount} entries',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                if (stats.errorCount > 0 || stats.warningCount > 0)
                                  Text(
                                    '${stats.errorCount} errors, ${stats.warningCount} warnings',
                                    style: const TextStyle(fontSize: 10, color: Colors.red),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        if (stats != null && stats.errorCount > 0)
                          Icon(Icons.error, color: Colors.red, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Dashboard View
class DashboardContentView extends StatelessWidget {
  final LogFileService logService;

  const DashboardContentView({super.key, required this.logService});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Dashboard Overview',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Last updated: ${DateTime.now().toString().substring(0, 19)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stats cards
          Row(
            children: [
              _DashboardCard(
                title: 'Total Entries',
                value: logService.totalCount.toString(),
                icon: Icons.description,
                color: Colors.blue,
              ),
              _DashboardCard(
                title: 'Errors',
                value: logService.errorCount.toString(),
                icon: Icons.error,
                color: Colors.red,
              ),
              _DashboardCard(
                title: 'Warnings',
                value: logService.warningCount.toString(),
                icon: Icons.warning,
                color: Colors.orange,
              ),
              _DashboardCard(
                title: 'Success Rate',
                value: '${((logService.totalCount - logService.errorCount) / logService.totalCount * 100).toStringAsFixed(1)}%',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Category breakdown and error patterns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CategoryBreakdownWidget(logService: logService),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _ErrorPatternsWidget(logService: logService),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 32),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdownWidget extends StatelessWidget {
  final LogFileService logService;

  const _CategoryBreakdownWidget({required this.logService});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...LogCategory.values.map((category) {
              final stats = logService.categorizationService.getStatsForCategory(category);
              if (stats == null || stats.totalCount == 0) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(category.icon, color: category.color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(category.displayName)),
                    Text('${stats.totalCount}'),
                    const SizedBox(width: 8),
                    if (stats.errorCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${stats.errorCount}',
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ErrorPatternsWidget extends StatelessWidget {
  final LogFileService logService;

  const _ErrorPatternsWidget({required this.logService});

  @override
  Widget build(BuildContext context) {
    final errorPatterns = logService.detectErrorPatterns();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Error Patterns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (errorPatterns.isEmpty)
              const Text(
                'No errors found',
                style: TextStyle(color: Colors.green),
              )
            else
              ...errorPatterns.map((pattern) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pattern.key,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pattern.value}x',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
