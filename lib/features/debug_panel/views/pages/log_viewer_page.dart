import 'dart:async';

import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/debug/log_toast_overlay.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/debug_panel/views/widgets/debug_widgets.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:flutter/material.dart';
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
          if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
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

  Future<void> _pickTag(Set<String> tags) async {
    final List<String> sorted = tags.toList()..sort();
    final String? picked = await showPrismSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => PrismSheetBody(
        title: 'Filter by tag',
        scrollable: true,
        child: PrismGroup(
          children: <Widget>[
            PrismRow(
              title: 'All tags',
              showChevron: false,
              trailing: _selectedTag == null ? const Icon(Icons.check_rounded, size: 20) : null,
              onTap: () => Navigator.of(sheetContext).pop(''),
            ),
            for (final String tag in sorted)
              PrismRow(
                title: tag,
                showChevron: false,
                trailing: _selectedTag == tag ? const Icon(Icons.check_rounded, size: 20) : null,
                onTap: () => Navigator.of(sheetContext).pop(tag),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedTag = picked.isEmpty ? null : picked);
  }

  Future<void> _clear() async {
    final bool ok = await showPrismConfirm(
      context,
      title: 'Clear logs?',
      message: 'This removes every log entry held in memory.',
      confirmLabel: 'Clear logs',
      destructive: true,
    );
    if (!ok || !mounted) return;
    InMemoryLogSink.instance.clear();
    setState(() => _records.clear());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final tags = _allTags;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.xs),
          child: DebugSearchField(controller: _searchCtrl, hintText: 'Search logs'),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
            scrollDirection: Axis.horizontal,
            children: [
              for (final level in AppLogLevel.values)
                Padding(
                  padding: const EdgeInsets.only(right: PrismSpace.xs),
                  child: PrismChip(
                    label: level.shortLabel,
                    selected: _selectedLevels.contains(level),
                    leading: DecoratedBox(
                      decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
                      child: const SizedBox.square(dimension: 8),
                    ),
                    onTap: () => setState(() {
                      if (!_selectedLevels.remove(level)) _selectedLevels.add(level);
                    }),
                  ),
                ),
              if (tags.isNotEmpty)
                PrismChip(
                  label: _selectedTag ?? 'All tags',
                  icon: Icons.sell_rounded,
                  selected: _selectedTag != null,
                  onTap: () => _pickTag(tags),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.xs, 0),
          child: Row(
            children: [
              Text('${filtered.length} entries', style: PrismTextStyles.caption(context)),
              const Spacer(),
              PrismIconButton(
                tooltip: _autoScroll ? 'Turn off auto-scroll' : 'Turn on auto-scroll',
                icon: Icons.vertical_align_bottom_rounded,
                filled: _autoScroll,
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
              PrismIconButton(
                tooltip: 'Copy all (filtered)',
                icon: Icons.copy_rounded,
                onPressed: () => copyToClipboard(context, _formatAll(filtered), label: 'Copied to clipboard'),
              ),
              PrismIconButton(
                tooltip: 'Export as file',
                icon: Icons.ios_share_rounded,
                onPressed: () {
                  SharePlus.instance.share(ShareParams(text: _formatAll(filtered), subject: 'Prism Debug Logs'));
                },
              ),
              PrismIconButton(tooltip: 'Clear', icon: Icons.delete_outline_rounded, onPressed: _clear),
            ],
          ),
        ),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
        Expanded(
          child: filtered.isEmpty
              ? GlintState(
                  kind: GlintStateKind.empty,
                  title: 'No logs',
                  body: _records.isEmpty
                      ? 'Log lines show up here as the app runs.'
                      : 'No log line matches the filters.',
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.only(bottom: PrismSpace.xl),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _LogEntryTile(record: filtered[i]),
                ),
        ),
      ],
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.record});
  final AppLogRecord record;

  String get _timeStr {
    final t = record.timestamp;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Color color = record.level.color;
    final bool hasDetail = record.error != null || record.stackTrace != null || record.fields.isNotEmpty;
    final TextStyle caption = PrismTextStyles.caption(context);

    final Widget row = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.level.shortLabel,
                      style: caption.copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                    if (record.tag != null) ...[
                      const SizedBox(width: PrismSpace.xs),
                      Flexible(
                        child: Text(record.tag!, maxLines: 1, overflow: TextOverflow.ellipsis, style: caption),
                      ),
                    ],
                    const Spacer(),
                    Text(_timeStr, style: debugMono(context, size: 11, alpha: 0.5)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(record.message, maxLines: 3, overflow: TextOverflow.ellipsis, style: debugMono(context)),
              ],
            ),
          ),
          if (hasDetail) ...[
            const SizedBox(width: PrismSpace.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ],
      ),
    );
    if (!hasDetail) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => showPrismSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _LogDetailSheet(record: record),
        ),
        child: row,
      ),
    );
  }
}

class _LogDetailSheet extends StatelessWidget {
  const _LogDetailSheet({required this.record});
  final AppLogRecord record;

  @override
  Widget build(BuildContext context) {
    final String stackTraceStr = record.stackTrace?.toString() ?? '';
    final String errorStr = record.error?.toString() ?? '';
    final ColorScheme cs = Theme.of(context).colorScheme;

    String fullDetail() {
      final buf = StringBuffer();
      buf.writeln('Time: ${record.timestamp.toIso8601String()}');
      buf.writeln('Level: ${record.level.name}');
      if (record.tag != null) buf.writeln('Tag: ${record.tag}');
      buf.writeln('Message: ${record.message}');
      if (errorStr.isNotEmpty) buf.writeln('\nError:\n$errorStr');
      if (stackTraceStr.isNotEmpty) buf.writeln('\nStackTrace:\n$stackTraceStr');
      if (record.fields.isNotEmpty) buf.writeln('\nFields: ${record.fields}');
      return buf.toString();
    }

    return PrismSheetBody(
      title: 'Log detail',
      scrollable: true,
      actions: <Widget>[
        PrismButton(
          label: 'Copy full detail',
          icon: Icons.copy_rounded,
          variant: PrismButtonVariant.tonal,
          expand: true,
          onPressed: () => copyToClipboard(context, fullDetail(), label: 'Copied to clipboard'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailRow(label: 'Time', value: record.timestamp.toIso8601String()),
          _DetailRow(label: 'Level', value: record.level.name.toUpperCase()),
          if (record.tag != null) _DetailRow(label: 'Tag', value: record.tag!),
          _DetailRow(label: 'Sequence', value: '#${record.sequence}'),
          _DetailRow(label: 'Message', value: record.message),
          if (record.fields.isNotEmpty) ...[
            const PrismSectionHeader(
              title: 'Fields',
              small: true,
              padding: EdgeInsets.only(top: PrismSpace.md),
            ),
            for (final e in record.fields.entries) _DetailRow(label: e.key, value: e.value?.toString() ?? 'null'),
          ],
          if (errorStr.isNotEmpty)
            _DetailBlock(
              title: 'Error',
              text: errorStr,
              color: cs.error,
              onCopy: () => copyToClipboard(context, errorStr, label: 'Error copied'),
            ),
          if (stackTraceStr.isNotEmpty)
            _DetailBlock(
              title: 'Stack trace',
              text: stackTraceStr,
              size: 11,
              onCopy: () => copyToClipboard(context, stackTraceStr, label: 'Stack trace copied'),
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
      padding: const EdgeInsets.only(bottom: PrismSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 84, child: Text(label, style: PrismTextStyles.caption(context))),
          Expanded(child: SelectableText(value, style: debugMono(context, size: 13))),
        ],
      ),
    );
  }
}

/// A titled block of selectable text with a copy button, for an error or a stack trace.
class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.text, required this.onCopy, this.color, this.size = 12});

  final String title;
  final String text;
  final VoidCallback onCopy;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final TextStyle mono = debugMono(context, size: size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: PrismSpace.md),
                child: Text(
                  title,
                  style: PrismTextStyles.caption(
                    context,
                  ).copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ),
            PrismIconButton(tooltip: 'Copy ${title.toLowerCase()}', icon: Icons.copy_rounded, onPressed: onCopy),
          ],
        ),
        SelectableText(text, style: color == null ? mono : mono.copyWith(color: color)),
      ],
    );
  }
}
