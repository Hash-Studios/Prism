import 'dart:async';

import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription<AppLogRecord>? _sub;

  final Set<AppLogLevel> _selectedLevels = AppLogLevel.values.toSet();
  String? _selectedTag;
  bool _autoScroll = true;
  List<AppLogRecord> _records = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _records = List<AppLogRecord>.from(InMemoryLogSink.instance.records);
    _sub = InMemoryLogSink.instance.stream.listen((record) {
      if (!mounted) return;
      setState(() => _records.add(record));
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<AppLogRecord> get _filtered {
    final query = _searchCtrl.text.toLowerCase();
    return _records.where((r) {
      if (!_selectedLevels.contains(r.level)) return false;
      if (_selectedTag != null && r.tag != _selectedTag) return false;
      if (query.isNotEmpty && !r.message.toLowerCase().contains(query)) return false;
      return true;
    }).toList();
  }

  Set<String> get _allTags {
    final tags = <String>{};
    for (final r in _records) {
      if (r.tag != null) tags.add(r.tag!);
    }
    return tags;
  }

  String _formatAll(List<AppLogRecord> records) {
    final buf = StringBuffer();
    for (final r in records) {
      final ts = r.timestamp.toIso8601String();
      final tag = r.tag != null ? '[${r.tag}] ' : '';
      buf.writeln('$ts ${r.level.shortLabel} $tag${r.message}');
      if (r.error != null) buf.writeln('  ERROR: ${r.error}');
      if (r.stackTrace != null) buf.writeln('  STACK: ${r.stackTrace}');
      if (r.fields.isNotEmpty) buf.writeln('  FIELDS: ${r.fields}');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;
    final tags = _allTags;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search logs...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear())
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        // Level chips
        SizedBox(
          height: 44,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            scrollDirection: Axis.horizontal,
            children: [
              for (final level in AppLogLevel.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(level.shortLabel, style: const TextStyle(fontSize: 11)),
                    selected: _selectedLevels.contains(level),
                    selectedColor: _levelColor(level).withValues(alpha: 0.3),
                    checkmarkColor: _levelColor(level),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedLevels.add(level);
                        } else {
                          _selectedLevels.remove(level);
                        }
                      });
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (tags.isNotEmpty) ...[
                const VerticalDivider(width: 16),
                DropdownButton<String?>(
                  value: _selectedTag,
                  hint: const Text('Tag', style: TextStyle(fontSize: 12)),
                  isDense: true,
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem<String?>(child: Text('All tags')),
                    ...tags.map(
                      (t) => DropdownMenuItem<String?>(
                        value: t,
                        child: Text(t, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedTag = v),
                ),
              ],
            ],
          ),
        ),
        // Action bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Text('${filtered.length} entries', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              IconButton(
                tooltip: 'Auto-scroll',
                icon: Icon(
                  _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
                  size: 18,
                  color: _autoScroll ? Theme.of(context).colorScheme.secondary : null,
                ),
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
              IconButton(
                tooltip: 'Copy all (filtered)',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _formatAll(filtered)));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)));
                },
              ),
              IconButton(
                tooltip: 'Export as file',
                icon: const Icon(Icons.share, size: 18),
                onPressed: () {
                  SharePlus.instance.share(ShareParams(text: _formatAll(filtered), subject: 'Prism Debug Logs'));
                },
              ),
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () {
                  InMemoryLogSink.instance.clear();
                  setState(() => _records.clear());
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Log list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No logs', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final record = filtered[i];
                    return _LogEntryTile(record: record);
                  },
                ),
        ),
      ],
    );
  }

  Color _levelColor(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.trace:
        return Colors.grey;
      case AppLogLevel.debug:
        return Colors.blueGrey;
      case AppLogLevel.info:
        return Colors.green;
      case AppLogLevel.warn:
        return Colors.orange;
      case AppLogLevel.error:
        return Colors.red;
      case AppLogLevel.fatal:
        return Colors.purple;
    }
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.record});
  final AppLogRecord record;

  static Color _levelColor(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.trace:
        return Colors.grey;
      case AppLogLevel.debug:
        return Colors.blueGrey;
      case AppLogLevel.info:
        return Colors.green;
      case AppLogLevel.warn:
        return Colors.orange;
      case AppLogLevel.error:
        return Colors.red;
      case AppLogLevel.fatal:
        return Colors.purple;
    }
  }

  String get _timeStr {
    final t = record.timestamp;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(record.level);
    final hasDetail = record.error != null || record.stackTrace != null || record.fields.isNotEmpty;

    return InkWell(
      onTap: hasDetail
          ? () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).primaryColor,
              builder: (_) => _LogDetailSheet(record: record),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _timeStr,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace'),
            ),
            const SizedBox(width: 6),
            Container(
              width: 28,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
              child: Text(
                record.level.shortLabel,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (record.tag != null)
                    Text(
                      record.tag!,
                      style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                    ),
                  Text(
                    record.message,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasDetail) Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _LogDetailSheet extends StatelessWidget {
  const _LogDetailSheet({required this.record});
  final AppLogRecord record;

  @override
  Widget build(BuildContext context) {
    final stackTraceStr = record.stackTrace?.toString() ?? '';
    final errorStr = record.error?.toString() ?? '';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Log Detail', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy full detail',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    final buf = StringBuffer();
                    buf.writeln('Time: ${record.timestamp.toIso8601String()}');
                    buf.writeln('Level: ${record.level.name}');
                    if (record.tag != null) buf.writeln('Tag: ${record.tag}');
                    buf.writeln('Message: ${record.message}');
                    if (errorStr.isNotEmpty) buf.writeln('\nError:\n$errorStr');
                    if (stackTraceStr.isNotEmpty) buf.writeln('\nStackTrace:\n$stackTraceStr');
                    if (record.fields.isNotEmpty) buf.writeln('\nFields: ${record.fields}');
                    Clipboard.setData(ClipboardData(text: buf.toString()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                _DetailRow(label: 'Time', value: record.timestamp.toIso8601String()),
                _DetailRow(label: 'Level', value: record.level.name.toUpperCase()),
                if (record.tag != null) _DetailRow(label: 'Tag', value: record.tag!),
                _DetailRow(label: 'Sequence', value: '#${record.sequence}'),
                _DetailRow(label: 'Message', value: record.message),
                if (record.fields.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Fields', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  for (final e in record.fields.entries) _DetailRow(label: e.key, value: e.value?.toString() ?? 'null'),
                ],
                if (errorStr.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Error',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: errorStr));
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Error copied'), duration: Duration(seconds: 1)));
                        },
                      ),
                    ],
                  ),
                  SelectableText(
                    errorStr,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.red),
                  ),
                ],
                if (stackTraceStr.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Stack Trace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: stackTraceStr));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Stack trace copied'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                  SelectableText(stackTraceStr, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
