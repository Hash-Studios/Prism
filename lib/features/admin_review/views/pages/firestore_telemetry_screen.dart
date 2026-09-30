import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

@RoutePage()
class FirestoreTelemetryScreen extends StatefulWidget {
  const FirestoreTelemetryScreen({super.key});

  @override
  State<FirestoreTelemetryScreen> createState() => _FirestoreTelemetryScreenState();
}

class _FirestoreTelemetryScreenState extends State<FirestoreTelemetryScreen> {
  String? _error;
  bool _loading = true;
  int _totalEvents = 0;
  int _docReads = 0;
  int _docWrites = 0;
  List<MapEntry<String, _CollectionStats>> _byCollection = <MapEntry<String, _CollectionStats>>[];
  List<MapEntry<String, int>> _byOperation = <MapEntry<String, int>>[];
  List<MapEntry<String, int>> _bySourceTag = <MapEntry<String, int>>[];
  String _rawContent = '';

  @override
  void initState() {
    super.initState();
    _loadTelemetry();
  }

  Future<void> _loadTelemetry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$firestoreTelemetryFileName');
      if (!file.existsSync()) {
        setState(() {
          _loading = false;
          _rawContent = '';
          _totalEvents = 0;
          _docReads = 0;
          _docWrites = 0;
          _byCollection = [];
          _byOperation = [];
          _bySourceTag = [];
        });
        return;
      }
      final content = await file.readAsString();
      final events = <_TelemetryEvent>[];
      for (final line in content.split('\n')) {
        if (line.trim().isEmpty) continue;
        final event = _TelemetryEvent.tryParse(line);
        if (event != null) {
          events.add(event);
        }
      }

      final docReads = events.fold<int>(0, (sum, e) => sum + e.reads);
      final docWrites = events.where((e) => e.isWrite).length;

      final byCollection = <String, _CollectionStats>{};
      for (final e in events) {
        final stats = byCollection.putIfAbsent(e.collection, _CollectionStats.new);
        stats.ops += 1;
        stats.reads += e.reads;
        if (e.isWrite) {
          stats.writes += 1;
        }
      }
      final byCollectionList = byCollection.entries.toList()..sort((a, b) => b.value.reads.compareTo(a.value.reads));

      final byOpList = _countBy(events, (e) => e.operation);
      final byTagList = _countBy(events, (e) => e.sourceTag);

      setState(() {
        _rawContent = content;
        _totalEvents = events.length;
        _docReads = docReads;
        _docWrites = docWrites;
        _byCollection = byCollectionList;
        _byOperation = byOpList;
        _bySourceTag = byTagList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copyAllData() async {
    if (_rawContent.isEmpty) {
      toasts.error('No telemetry data to copy');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _rawContent));
    toasts.success('Copied to clipboard. Paste elsewhere to analyze.');
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Firestore telemetry',
      actions: <Widget>[
        PrismIconButton(icon: Icons.refresh_rounded, tooltip: 'Refresh', onPressed: _loading ? null : _loadTelemetry),
      ],
      body: _loading
          ? PrismSkeleton.cards(height: 140)
          : _error != null
          ? GlintState(
              kind: GlintStateKind.error,
              title: 'Could not read telemetry',
              body: _error,
              actionLabel: 'Try again',
              onAction: _loadTelemetry,
            )
          : _rawContent.isEmpty
          ? const GlintState(
              kind: GlintStateKind.empty,
              title: 'No telemetry yet',
              body: 'Use the app to generate Firestore events.',
            )
          : RefreshIndicator(
              onRefresh: _loadTelemetry,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxl),
                children: <Widget>[
                  PrismCard(
                    child: Column(
                      children: <Widget>[
                        _StatRow('Total events', '$_totalEvents'),
                        _StatRow('Estimated document reads', '$_docReads'),
                        _StatRow('Estimated document writes', '$_docWrites'),
                      ],
                    ),
                  ),
                  const SizedBox(height: PrismSpace.sm),
                  PrismButton(
                    label: 'Copy all data',
                    icon: Icons.copy_rounded,
                    variant: PrismButtonVariant.tonal,
                    expand: true,
                    onPressed: _copyAllData,
                  ),
                  _StatsSection(
                    title: 'By collection',
                    rows: <PrismRow>[
                      for (final e in _byCollection)
                        PrismRow(
                          icon: Icons.folder_outlined,
                          title: _middleEllipsis(e.key),
                          subtitle:
                              '${_count(e.value.reads, 'read')} · ${_count(e.value.writes, 'write')} · ${_count(e.value.ops, 'op')}',
                        ),
                    ],
                  ),
                  _StatsSection(
                    title: 'By operation',
                    rows: <PrismRow>[
                      for (final e in _byOperation)
                        PrismRow(icon: Icons.bolt_rounded, title: e.key, value: '${e.value}'),
                    ],
                  ),
                  _StatsSection(
                    title: 'By source (top 15)',
                    rows: <PrismRow>[
                      for (final e in _bySourceTag.take(15))
                        PrismRow(icon: Icons.sell_outlined, title: _middleEllipsis(e.key), value: '${e.value}'),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

/// Keeps the start and end of a long path, such as a user document path, and drops the middle.
String _middleEllipsis(String text, {int max = 40}) {
  if (text.length <= max) return text;
  final int keep = (max - 1) ~/ 2;
  return '${text.substring(0, keep)}…${text.substring(text.length - keep)}';
}

List<MapEntry<String, int>> _countBy(List<_TelemetryEvent> events, String Function(_TelemetryEvent) key) {
  final counts = <String, int>{};
  for (final e in events) {
    counts.update(key(e), (n) => n + 1, ifAbsent: () => 1);
  }
  return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.title, required this.rows});

  final String title;
  final List<PrismRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PrismSectionHeader(
          title: title,
          small: true,
          padding: const EdgeInsets.only(top: PrismSpace.xl, bottom: PrismSpace.xs, left: PrismSpace.xxs),
        ),
        PrismGroup(children: rows),
      ],
    );
  }
}

class _CollectionStats {
  int reads = 0;
  int writes = 0;
  int ops = 0;
}

class _TelemetryEvent {
  const _TelemetryEvent({
    required this.operation,
    required this.resultCount,
    required this.collection,
    required this.sourceTag,
  });

  final String operation;
  final int? resultCount;
  final String collection;
  final String sourceTag;

  FirestoreOperation? get _op => FirestoreOperation.values.asNameMap()[operation];
  int get reads => (_op?.isRead ?? false) ? resultCount ?? 1 : 0;
  bool get isWrite => _op?.isWrite ?? false;

  static _TelemetryEvent? tryParse(String line) {
    try {
      final Object? raw = jsonDecode(line);
      if (raw is! Map<String, dynamic>) {
        return null;
      }
      return _TelemetryEvent(
        operation: _readString(raw, 'operation', fallback: 'unknown'),
        resultCount: _readInt(raw, 'resultCount'),
        collection: _readString(raw, 'collection', fallback: 'unknown'),
        sourceTag: _readString(raw, 'sourceTag', fallback: 'unknown'),
      );
    } catch (_) {
      return null;
    }
  }

  static String _readString(Map<String, dynamic> data, String key, {required String fallback}) {
    final Object? value = data[key];
    final String output = value?.toString().trim() ?? '';
    return output.isEmpty ? fallback : output;
  }

  static int? _readInt(Map<String, dynamic> data, String key) {
    final Object? value = data[key];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(child: Text(label, style: PrismTextStyles.body(context))),
          const SizedBox(width: PrismSpace.sm),
          Text(value, style: PrismTextStyles.rowTitle(context)),
        ],
      ),
    );
  }
}
