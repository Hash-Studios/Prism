import 'dart:convert';

import 'package:Prism/core/debug/performance_probe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

class _FrameBinding extends AutomatedTestWidgetsFlutterBinding {
  late TimingsCallback timings;

  @override
  void addTimingsCallback(TimingsCallback callback) => timings = callback;
}

FrameTiming _frame(int buildMicros) => FrameTiming(
  vsyncStart: 0,
  buildStart: 0,
  buildFinish: buildMicros,
  rasterStart: buildMicros,
  rasterFinish: buildMicros + 1000,
  rasterFinishWallTime: buildMicros + 1000,
);

void main() {
  final _FrameBinding binding = _FrameBinding();

  test('long sessions retain a bounded recent frame window and report omitted samples', () {
    final DebugPrintCallback previous = debugPrint;
    final List<Map<String, dynamic>> samples = <Map<String, dynamic>>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message?.startsWith('PRISM_PERF ') ?? false) {
        samples.add(jsonDecode(message!.substring('PRISM_PERF '.length)) as Map<String, dynamic>);
      }
    };
    addTearDown(() => debugPrint = previous);

    PerformanceProbe.startFrameStats();
    binding.timings(List<FrameTiming>.generate(4000, (int index) => _frame(index + 1)));
    PerformanceProbe.phase('next');

    expect(samples.single['name'], 'startup');
    expect(samples.single['extra'], <String, Object?>{
      'count': 3600,
      'dropped_frames': 400,
      'build_p50_us': 2201,
      'build_p90_us': 3640,
      'build_p99_us': 3964,
      'build_max_us': 4000,
      'raster_max_us': 1000,
      'raster_p90_us': 1000,
      'raster_p99_us': 1000,
      'total_p90_us': 4640,
      'over_16ms': 0,
      'over_33ms': 0,
    });

    binding.timings(<FrameTiming>[_frame(100)]);
    PerformanceProbe.phase('done');
    expect(samples.last['name'], 'next');
    final Map<String, dynamic> extra = samples.last['extra'] as Map<String, dynamic>;
    expect(extra['count'], 1);
    expect(extra['dropped_frames'], 0);
    expect(extra['build_max_us'], 100);
  });
}
