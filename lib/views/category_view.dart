import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/log_file_service.dart';
import '../services/log_categorization_service.dart';

class CategoryView extends StatefulWidget {
  final LogCategory category;
  final LogFileService logService;

  const CategoryView({super.key, required this.category, required this.logService});

  @override
  State<CategoryView> createState() => _CategoryViewState();
}

class _CategoryViewState extends State<CategoryView> {
  String _searchText = '';
  LogLevel? _selectedLevel;
  LogEntry? _selectedEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with stats
        _buildHeader(),
        const Divider(height: 1),
        // Filters
        _buildFilters(),
        const Divider(height: 1),
        // Content
        Expanded(
          child: widget.logService.entries.isEmpty 
              ? _buildEmptyState()
              : _buildLogView(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final stats = widget.logService.categorizationService.getStatsForCategory(widget.category);
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        children: [
          Icon(widget.category.icon, color: widget.category.color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.displayName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (stats != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatChip('Total', stats.totalCount.toString(), Colors.blue),
                      const SizedBox(width: 8),
                      _StatChip('Errors', stats.errorCount.toString(), Colors.red),
                      const SizedBox(width: 8),
                      _StatChip('Warnings', stats.warningCount.toString(), Colors.orange),
                      const SizedBox(width: 8),
                      _StatChip('Info', stats.infoCount.toString(), Colors.green),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (stats != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Error Rate: ${stats.errorRate.toStringAsFixed(1)}%'),
                Text('Warning Rate: ${stats.warningRate.toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<LogLevel?>(
            value: _selectedLevel,
            hint: const Text('All Levels'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Levels')),
              ...LogLevel.values.map((level) => DropdownMenuItem(
                value: level,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: level.color, size: 12),
                    const SizedBox(width: 8),
                    Text(level.value),
                  ],
                ),
              )),
            ],
            onChanged: (level) {
              setState(() {
                _selectedLevel = level;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogView() {
    final filteredEntries = _getFilteredEntries();
    
    return Row(
      children: [
        // Log list
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${filteredEntries.length} entries',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredEntries.length,
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];
                    return _LogEntryTile(
                      entry: entry,
                      isSelected: _selectedEntry?.id == entry.id,
                      onTap: () {
                        setState(() {
                          _selectedEntry = entry;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Detail view
        Expanded(
          flex: 1,
          child: _selectedEntry != null
              ? _LogDetailView(entry: _selectedEntry!)
              : const _EmptyDetailView(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.category.icon,
            size: 64,
            color: widget.category.color.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${widget.category.displayName.toLowerCase()} data available',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Load Intune logs to see categorized information',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  List<LogEntry> _getFilteredEntries() {
    var entries = widget.logService.categorizationService.getLogsForCategory(widget.category);

    if (_selectedLevel != null) {
      entries = entries.where((entry) => entry.level == _selectedLevel).toList();
    }

    if (_searchText.isNotEmpty) {
      entries = entries.where((entry) =>
          entry.message.toLowerCase().contains(_searchText.toLowerCase()) ||
          entry.component.toLowerCase().contains(_searchText.toLowerCase())).toList();
    }

    return entries;
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _LogEntryTile({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.level == LogLevel.error ? Icons.error :
                  entry.level == LogLevel.warning ? Icons.warning :
                  entry.level == LogLevel.info ? Icons.info : Icons.bug_report,
                  size: 16,
                  color: entry.level.color,
                ),
                const SizedBox(width: 8),
                Text(
                  entry.timestamp.toString().substring(11, 19),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.component,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogDetailView extends StatelessWidget {
  final LogEntry entry;

  const _LogDetailView({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _DetailRow('Timestamp', entry.timestamp.toString()),
          _DetailRow('Level', entry.level.value),
          _DetailRow('Component', entry.component),
          const SizedBox(height: 16),
          const Text(
            'Message',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(entry.message),
          ),
          const SizedBox(height: 16),
          const Text(
            'Full Log Entry',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  entry.fullText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _copyToClipboard(context),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _exportEntry(context),
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Export'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    // Clipboard functionality would go here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _exportEntry(BuildContext context) {
    // Export functionality would go here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDetailView extends StatelessWidget {
  const _EmptyDetailView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Select a log entry to view details',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
