// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/analytics/analytics_route_observer.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/debug/perf_autodrive.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/env/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/fake_app_analytics.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  int postFrameCallbacks = 0;

  @override
  void addPostFrameCallback(FrameCallback callback, {String debugLabel = 'callback'}) {
    postFrameCallbacks++;
    super.addPostFrameCallback(callback, debugLabel: debugLabel);
  }
}

class _Paths extends PathProviderPlatform {
  int calls = 0;

  @override
  Future<String?> getApplicationDocumentsPath() {
    calls++;
    throw StateError('release probe accessed storage');
  }
}

class _Event extends AnalyticsEvent {
  int serializations = 0;

  @override
  String get eventName => 'test';

  @override
  Map<String, Object?> toWireParameters() {
    serializations++;
    return <String, Object?>{'duration_ms': 3};
  }
}

class _Router implements AppRouter {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('release autodrive accessed router');
}

void main() {
  final _Binding binding = _Binding();

  test('release probes leave storage, frames and operation results alone', () async {
    final PathProviderPlatform previousPaths = PathProviderPlatform.instance;
    final _Paths paths = _Paths();
    PathProviderPlatform.instance = paths;
    final DebugPrintCallback previousPrint = debugPrint;
    final List<String?> messages = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
    addTearDown(() {
      PathProviderPlatform.instance = previousPaths;
      debugPrint = previousPrint;
    });
    final int callbacks = binding.postFrameCallbacks;
    PerformanceProbe.mark('startup.binding_ready');
    PerformanceProbe.markOnce('home.grid_first_paint');
    PerformanceProbe.emit(kind: 'test', name: 'test', durationMs: 2);
    expect(await PerformanceProbe.measure('test', 'test', () async => 42), 42);
    final StateError failure = StateError('operation failed');
    await expectLater(
      PerformanceProbe.measure<void>('test', 'test', () async => throw failure),
      throwsA(same(failure)),
    );
    expect(PerformanceProbe.sinceProcess.isRunning, isFalse);
    expect(paths.calls, 0);
    expect(messages, isEmpty);
    expect(binding.postFrameCallbacks, callbacks);
  }, skip: !kReleaseMode);

  test('release analytics forwards events without probe serialization or frame callbacks', () async {
    final BufferedAppAnalytics buffer = BufferedAppAnalytics();
    final FakeAppAnalytics target = FakeAppAnalytics();
    buffer.attach(target);
    final _Event event = _Event();
    await buffer.track(event);
    expect(target.events, <AnalyticsEvent>[event]);
    expect(event.serializations, 0);
    final List<String> screens = <String>[];
    final AnalyticsRouteObserver observer = AnalyticsRouteObserver(
      onScreenView: ({required String screenName, String? screenClass, Map<String, Object?>? parameters}) async {
        screens.add(screenName);
      },
    );
    final int callbacks = binding.postFrameCallbacks;
    observer.didPush(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: '/home'),
        pageBuilder: (_, _, _) => const SizedBox(),
      ),
      null,
    );
    expect(screens, <String>['/home']);
    expect(binding.postFrameCallbacks, callbacks);
    buffer.dispose();
  }, skip: !kReleaseMode);

  test('release autodrive stays off with its flag enabled', () {
    expect(Env.perfAutodrive, isTrue);
    expect(() => PerfAutodrive.start(_Router()), returnsNormally);
  }, skip: !kReleaseMode);
}
