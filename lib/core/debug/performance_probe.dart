import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Latency probe for debug and profile builds; release builds skip it. Every sample is a single `PRISM_PERF {json}` line on stdout
/// and one NDJSON line in the app documents directory (`performance_probe.ndjson`).
class PerformanceProbe {
  PerformanceProbe._();

  static const String logPrefix = 'PRISM_PERF';
  static const String fileName = 'performance_probe.ndjson';

  static final Stopwatch sinceProcess = kReleaseMode ? Stopwatch() : (Stopwatch()..start());

  static File? _file;
  static Future<void> _writeTail = Future<void>.value();

  static final Set<String> _marked = <String>{};

  static const Map<String, String> _launchMilestones = <String, String>{
    'startup.binding_ready': 'pre_main',
    'startup.first_frame': 'tap_to_first_frame',
    'time_to_home': 'tap_to_home',
    'home.grid_first_paint': 'tap_to_grid',
  };

  /// When the kernel started this process, on iOS. Null elsewhere and for prewarmed launches, which start long before
  /// the tap.
  static final DateTime? _processStart = _readProcessStart();

  static DateTime? _readProcessStart() {
    if (kReleaseMode || !Platform.isIOS || Platform.environment['ActivePrewarm'] == '1') return null;
    const int procPidTbsdInfo = 3;
    const int bsdInfoSize = 136;
    try {
      final DynamicLibrary lib = DynamicLibrary.process();
      final int Function() getpid = lib.lookupFunction<Int32 Function(), int Function()>('getpid');
      final Pointer<Void> Function(int) malloc = lib
          .lookupFunction<Pointer<Void> Function(IntPtr), Pointer<Void> Function(int)>('malloc');
      final void Function(Pointer<Void>) free = lib
          .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('free');
      final int Function(int, int, int, Pointer<Void>, int) procPidInfo = lib
          .lookupFunction<
            Int32 Function(Int32, Int32, Uint64, Pointer<Void>, Int32),
            int Function(int, int, int, Pointer<Void>, int)
          >('proc_pidinfo');
      final Pointer<Void> info = malloc(bsdInfoSize);
      try {
        if (procPidInfo(getpid(), procPidTbsdInfo, 0, info, bsdInfoSize) != bsdInfoSize) return null;
        final int seconds = Pointer<Uint64>.fromAddress(info.address + 120).value;
        final int micros = Pointer<Uint64>.fromAddress(info.address + 128).value;
        return DateTime.fromMicrosecondsSinceEpoch(seconds * Duration.microsecondsPerSecond + micros);
      } finally {
        free(info);
      }
    } catch (_) {
      return null;
    }
  }

  static String _phase = 'startup';
  static final List<FrameTiming> _frames = <FrameTiming>[];

  /// Collects frame timings. [phase] emits one `frames` sample for the frames since the previous phase.
  static void startFrameStats() {
    if (kReleaseMode) return;
    SchedulerBinding.instance.addTimingsCallback(_frames.addAll);
  }

  /// Starts a named frame window. Wait about 1 s before a change: the engine reports timings in batches.
  static void phase(String name) {
    if (kReleaseMode) return;
    if (_frames.isNotEmpty) {
      List<int> sorted(Duration Function(FrameTiming) of) =>
          _frames.map((FrameTiming t) => of(t).inMicroseconds).toList()..sort();
      int pct(List<int> v, double q) => v[((v.length - 1) * q).round()];
      final List<int> build = sorted((FrameTiming t) => t.buildDuration);
      final List<int> raster = sorted((FrameTiming t) => t.rasterDuration);
      final List<int> total = sorted((FrameTiming t) => t.totalSpan);
      emit(
        kind: 'frames',
        name: _phase,
        durationMs: total.last ~/ 1000,
        extra: <String, Object?>{
          'count': total.length,
          'build_p50_us': pct(build, 0.5),
          'build_p90_us': pct(build, 0.9),
          'build_p99_us': pct(build, 0.99),
          'build_max_us': build.last,
          'raster_max_us': raster.last,
          'raster_p90_us': pct(raster, 0.9),
          'raster_p99_us': pct(raster, 0.99),
          'total_p90_us': pct(total, 0.9),
          'over_16ms': total.where((int v) => v > 16667).length,
          'over_33ms': total.where((int v) => v > 33333).length,
        },
      );
      _frames.clear();
    }
    _phase = name;
  }

  /// Marks [name] once per process, after the frame that is being built paints.
  static void markOnce(String name) {
    if (kReleaseMode || !_marked.add(name)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => mark(name));
  }

  static void mark(String name, {Map<String, Object?> extra = const <String, Object?>{}}) {
    if (kReleaseMode) return;
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
    final String? milestone = _launchMilestones[name];
    final DateTime? start = _processStart;
    if (milestone != null && start != null && kind != 'cold_launch') {
      emit(kind: 'cold_launch', name: milestone, durationMs: DateTime.now().difference(start).inMilliseconds);
    }
  }

  static Future<void> _append(Map<String, Object?> payload) {
    final Future<void> prev = _writeTail;
    late final Future<void> next;
    next = prev.then((_) async {
      try {
        final File file = await _resolveFile();
        await file.writeAsString('${jsonEncode(payload)}\n', mode: FileMode.append, flush: true);
        if (await file.length() > 2 * 1024 * 1024) {
          final List<String> lines = await file.readAsLines();
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
