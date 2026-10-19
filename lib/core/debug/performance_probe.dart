import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Latency probe for debug and profile builds; release builds skip it. Every sample is a single `PRISM_PERF {json}` line on stdout
/// and one NDJSON line in the app documents directory (`performance_probe.ndjson`).
class PerformanceProbe {
  PerformanceProbe._();

  static const String logPrefix = 'PRISM_PERF';
  static const String fileName = 'performance_probe.ndjson';

  static final Stopwatch sinceProcess = Stopwatch()..start();

  static File? _file;
  static Future<void> _writeTail = Future<void>.value();

  static final Set<String> _marked = <String>{};

  /// Marks [name] once per process, after the frame that is being built paints.
  static void markOnce(String name) {
    if (kReleaseMode || !_marked.add(name)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => mark(name));
  }

  static void mark(String name, {Map<String, Object?> extra = const <String, Object?>{}}) {
    emit(kind: 'mark', name: name, durationMs: sinceProcess.elapsedMilliseconds, extra: extra);
  }

  static Future<T> measure<T>(
    String kind,
    String name,
    Future<T> Function() action, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    if (kReleaseMode) return action();
    final Stopwatch sw = Stopwatch()..start();
    try {
      final T result = await action();
      emit(kind: kind, name: name, durationMs: sw.elapsedMilliseconds, extra: extra);
      return result;
    } catch (error) {
      emit(
        kind: kind,
        name: name,
        durationMs: sw.elapsedMilliseconds,
        success: false,
        extra: <String, Object?>{...extra, 'error': error.runtimeType.toString()},
      );
      rethrow;
    }
  }

  static void emit({
    required String kind,
    required String name,
    required int durationMs,
    bool success = true,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    if (kReleaseMode) return;
    final Map<String, Object?> payload = <String, Object?>{
      'kind': kind,
      'name': name,
      'ms': durationMs,
      'ok': success,
      'since_start_ms': sinceProcess.elapsedMilliseconds,
      'ts': DateTime.now().toUtc().toIso8601String(),
      if (extra.isNotEmpty) 'extra': extra,
    };
    debugPrint('$logPrefix ${jsonEncode(payload)}');
    unawaited(_append(payload));
  }

  static Future<void> _append(Map<String, Object?> payload) {
    final Future<void> prev = _writeTail;
    late final Future<void> next;
    next = prev.then((_) async {
      try {
        final File file = await _resolveFile();
        await file.writeAsString('${jsonEncode(payload)}\n', mode: FileMode.append, flush: true);
        if (file.lengthSync() > 2 * 1024 * 1024) {
          final List<String> lines = file.readAsLinesSync();
          await file.writeAsString('${lines.skip(lines.length ~/ 2).join('\n')}\n');
        }
      } catch (_) {
        // Probe must never break the app. Stdout already has the sample.
      }
    });
    _writeTail = next;
    return next;
  }

  static Future<File> _resolveFile() async {
    if (_file != null) return _file!;
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/$fileName');
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    _file = file;
    return file;
  }
}
