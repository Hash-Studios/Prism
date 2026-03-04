import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const String _kTelemetryFileName = 'firestore_telemetry.ndjson';

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
      final file = File('${dir.path}/$_kTelemetryFileName');
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

      final readOps = events.where((e) {
        return e.operation == 'queryGet' || e.operation == 'docGet' || e.operation == 'streamSubscribe';
      }).toList();
      final writeOps = events.where((e) {
        return e.operation == 'set' ||
            e.operation == 'update' ||
            e.operation == 'delete' ||
            e.operation == 'add' ||
            e.operation == 'transaction';
      }).toList();

      final docReads = readOps.fold<int>(0, (sum, e) => sum + (e.resultCount ?? 1));
      final docWrites = writeOps.length;

      final byCollection = <String, _CollectionStats>{};
      for (final e in events) {
        final c = e.collection;
        final stats = byCollection.putIfAbsent(c, _CollectionStats.new);
        stats.ops += 1;
        final op = e.operation;
        if (op == 'queryGet' || op == 'docGet' || op == 'streamSubscribe') {
          stats.reads += e.resultCount ?? 1;
        } else if (op == 'set' || op == 'update' || op == 'delete' || op == 'add' || op == 'transaction') {
          stats.writes += 1;
        }
      }
      final byCollectionList = byCollection.entries.toList()..sort((a, b) => b.value.reads.compareTo(a.value.reads));

      final byOp = <String, int>{};
      for (final e in events) {
        final op = e.operation;
        byOp[op] = (byOp[op] ?? 0) + 1;
      }
      final byOpList = byOp.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      final byTag = <String, int>{};
      for (final e in events) {
        final tag = e.sourceTag;
        byTag[tag] = (byTag[tag] ?? 0) + 1;
      }
      final byTagList = byTag.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

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
    toasts.codeSend('Copied to clipboard. Paste elsewhere to analyze.');
  }

  @override
  Widget build(BuildContext context) {
    if (!app_state.isAdminUser()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Firestore telemetry')),
        body: const Center(child: Text('You are not authorized to access this page.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore telemetry'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _loadTelemetry, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _loadTelemetry, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTelemetry,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            _StatRow('Total events', '$_totalEvents'),
                            _StatRow('Estimated document reads', '$_docReads'),
                            _StatRow('Estimated document writes', '$_docWrites'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _rawContent.isEmpty ? null : _copyAllData,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy all data (NDJSON)'),
                    ),
                    if (_rawContent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'No telemetry recorded yet. Use the app to generate Firestore events.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_byCollection.isNotEmpty) ...[
                      Text('By collection', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _byCollection.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = _byCollection[i];
                            return ListTile(
                              title: Text(e.key),
                              subtitle: Text('${e.value.reads} reads, ${e.value.writes} writes, ${e.value.ops} ops'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_byOperation.isNotEmpty) ...[
                      Text('By operation', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _byOperation.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = _byOperation[i];
                            return ListTile(title: Text(e.key), trailing: Text('${e.value}'));
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_bySourceTag.isNotEmpty) ...[
                      Text('By source (top 15)', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _bySourceTag.length > 15 ? 15 : _bySourceTag.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = _bySourceTag[i];
                            return ListTile(
                              title: Text(e.key, overflow: TextOverflow.ellipsis),
                              trailing: Text('${e.value}'),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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

  static Object? _readValue(Map<String, dynamic> data, String key) => data[key];

  static String _readString(Map<String, dynamic> data, String key, {required String fallback}) {
    final Object? value = _readValue(data, key);
    final String output = value?.toString().trim() ?? '';
    return output.isEmpty ? fallback : output;
  }

  static int? _readInt(Map<String, dynamic> data, String key) {
    final Object? value = _readValue(data, key);
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
