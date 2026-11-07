import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/debug/perf_autodrive.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/env/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _LifecycleBinding extends AutomatedTestWidgetsFlutterBinding {
  late TimingsCallback timings;

  @override
  void addTimingsCallback(TimingsCallback callback) => timings = callback;
}

class _BlockedSettings extends SettingsLocalDataSource {
  _BlockedSettings() : super(InMemoryLocalStore());

  @override
  Future<void> set(String key, Object? value) => Completer<void>().future;
}

class _UntouchedRouter implements AppRouter {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('script advanced past blocked persistence');
}

FrameTiming _frame() => FrameTiming(
  vsyncStart: 0,
  buildStart: 0,
  buildFinish: 1000,
  rasterStart: 1000,
  rasterFinish: 2000,
  rasterFinishWallTime: 2000,
);

void main() {
  final _LifecycleBinding binding = _LifecycleBinding();

  testWidgets('a paused or newer resume window is not overwritten by an earlier resume timer', (tester) async {
    final DebugPrintCallback previous = debugPrint;
    final List<Map<String, dynamic>> samples = <Map<String, dynamic>>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message?.startsWith('PRISM_PERF ') ?? false) {
        samples.add(jsonDecode(message!.substring('PRISM_PERF '.length)) as Map<String, dynamic>);
      }
    };
    try {
      getIt.registerSingleton<SettingsLocalDataSource>(_BlockedSettings());
      addTearDown(getIt.reset);
      PerformanceProbe.startFrameStats();
      PerfAutodrive.start(_UntouchedRouter());
      await tester.pump();

      void pause() {
        binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
          ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }

      void resume() {
        binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }

      String lastFrameWindow() => samples.lastWhere((sample) => sample['kind'] == 'frames')['name'] as String;

      pause();
      resume();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      pause();
      await tester.pump(const Duration(seconds: 4));
      binding.timings(<FrameTiming>[_frame()]);
      PerformanceProbe.phase('checkpoint');
      expect(lastFrameWindow(), 'paused');

      resume();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      pause();
      resume();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      binding.timings(<FrameTiming>[_frame()]);
      PerformanceProbe.phase('checkpoint');
      expect(lastFrameWindow(), 'resume');
      await tester.pump(const Duration(seconds: 1));
      binding.timings(<FrameTiming>[_frame()]);
      PerformanceProbe.phase('done');
      expect(lastFrameWindow(), 'after_resume');
      pause();
    } finally {
      debugPrint = previous;
    }
  }, skip: !Env.perfAutodrive);
}
