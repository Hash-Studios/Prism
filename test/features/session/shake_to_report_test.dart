import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/session/data/shake_to_report.dart';
import 'package:Prism/features/session/views/widgets/shake_to_report_listener.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

DateTime _at(int ms) => DateTime.utc(2026).add(Duration(milliseconds: ms));

class _FakeImage extends Fake implements ui.Image {
  bool disposed = false;

  @override
  void dispose() => disposed = true;
}

class _MemoryLocalStore extends Fake implements LocalStore {
  final Map<String, Object?> values = <String, Object?>{};

  @override
  bool get isReady => true;

  @override
  Object? get(String key) => values[key];

  @override
  Future<void> set(String key, Object? value) async {
    values[key] = value;
  }
}

void main() {
  group('ShakeDetector', () {
    test('three strong jolts inside the window make one shake, then it stays quiet for the cooldown', () {
      final detector = ShakeDetector();

      expect(detector.add(25, 0, 0, _at(0)), isFalse);
      expect(detector.add(0, -25, 0, _at(200)), isFalse);
      expect(detector.add(0, 0, 25, _at(400)), isTrue);
      expect(<bool>[for (var t = 600; t < 3400; t += 200) detector.add(25, 0, 0, _at(t))], everyElement(isFalse));
      expect(detector.add(25, 0, 0, _at(3600)), isFalse);
      expect(detector.add(25, 0, 0, _at(3800)), isFalse);
      expect(detector.add(25, 0, 0, _at(4000)), isTrue);
    });

    test('ignores gentle motion, jolts spread too far apart, and samples of the same jolt', () {
      final detector = ShakeDetector();

      expect(<bool>[for (var t = 0; t < 2000; t += 20) detector.add(8, 8, 8, _at(t))], everyElement(isFalse));
      expect(<bool>[
        for (final t in <int>[3000, 4000, 5000, 6000]) detector.add(30, 0, 0, _at(t)),
      ], everyElement(isFalse));
      expect(<bool>[for (var t = 7000; t < 7100; t += 16) detector.add(30, 0, 0, _at(t))], everyElement(isFalse));
    });

    test('reset drops partial jolts but preserves the cooldown', () {
      final detector = ShakeDetector();

      expect(detector.add(30, 0, 0, _at(0)), isFalse);
      expect(detector.add(30, 0, 0, _at(200)), isFalse);
      detector.reset();
      expect(detector.add(30, 0, 0, _at(400)), isFalse);
      expect(detector.add(30, 0, 0, _at(600)), isFalse);
      expect(detector.add(30, 0, 0, _at(800)), isTrue);
      detector.reset();
      expect(detector.add(30, 0, 0, _at(1000)), isFalse);
    });
  });

  group('ShakeToReportListener', () {
    late StreamController<UserAccelerometerEvent> sensor;

    setUp(() {
      AnalyticsRuntime.instance = FakeAppAnalytics();
      app_state.prismUser = profileUser(id: 'user-1', loggedIn: false);
      sensor = StreamController<UserAccelerometerEvent>.broadcast();
      ShakeToReport.enabled.value = true;
    });
    tearDown(() async {
      AnalyticsRuntime.reset();
      await sensor.close();
    });

    Future<GlobalKey<NavigatorState>> pumpApp(
      WidgetTester tester, {
      ScreenshotCapture? captureScreenshot,
      GlobalKey<NavigatorState>? navigatorKey,
      bool includeOpenSheetButton = false,
      AccelerometerStream? accelerometer,
    }) async {
      final key = navigatorKey ?? GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => ShakeToReportListener(
            navigatorKey: key,
            accelerometer: accelerometer ?? () => sensor.stream,
            captureScreenshot: captureScreenshot,
            child: child!,
          ),
          home: Scaffold(
            body: Column(
              children: <Widget>[
                const Text('home'),
                if (includeOpenSheetButton)
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showPrismSheet<void>(context, builder: (_) => const Text('existing sheet')),
                      child: const Text('Open sheet'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return key;
    }

    Future<void> pumpBareApp(WidgetTester tester, GlobalKey<NavigatorState> navigatorKey) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('bare app')),
        ),
      );
    }

    Future<void> shake(WidgetTester tester, int startMs) async {
      for (var i = 0; i < 3; i++) {
        sensor.add(UserAccelerometerEvent(30, 0, 0, _at(startMs + i * 200)));
      }
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> startShake(WidgetTester tester, int startMs) async {
      for (var i = 0; i < 3; i++) {
        sensor.add(UserAccelerometerEvent(30, 0, 0, _at(startMs + i * 200)));
      }
      await tester.pump();
    }

    Future<void> settleSensor(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }

    Future<void> finishCapture(WidgetTester tester, Completer<Uint8List?> capture) async {
      capture.complete(null);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('does not open after another Prism sheet opens during capture', (tester) async {
      final Completer<Uint8List?> capture = Completer<Uint8List?>();
      bool captureStarted = false;
      await pumpApp(
        tester,
        captureScreenshot: () {
          captureStarted = true;
          return capture.future;
        },
        includeOpenSheetButton: true,
      );

      await startShake(tester, 0);
      expect(captureStarted, isTrue);
      await tester.tap(find.text('Open sheet'));
      await tester.pump();
      await finishCapture(tester, capture);

      expect(find.text('existing sheet'), findsOneWidget);
      expect(find.text('Report a problem'), findsNothing);
    });

    testWidgets('does not open after the setting is disabled during capture', (tester) async {
      final Completer<Uint8List?> capture = Completer<Uint8List?>();
      bool captureStarted = false;
      bool captureFinished = false;
      await pumpApp(
        tester,
        captureScreenshot: () async {
          captureStarted = true;
          final Uint8List? result = await capture.future;
          captureFinished = true;
          return result;
        },
      );

      await startShake(tester, 0);
      expect(captureStarted, isTrue);
      ShakeToReport.enabled.value = false;
      await tester.pump();
      await finishCapture(tester, capture);
      expect(captureFinished, isTrue);

      expect(find.text('Report a problem'), findsNothing);
      expect(sensor.hasListener, isFalse);
    });

    testWidgets('does not open after the app backgrounds during capture', (tester) async {
      final Completer<Uint8List?> capture = Completer<Uint8List?>();
      bool captureStarted = false;
      await pumpApp(
        tester,
        captureScreenshot: () {
          captureStarted = true;
          return capture.future;
        },
      );

      await startShake(tester, 0);
      expect(captureStarted, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await finishCapture(tester, capture);

      expect(find.text('Report a problem'), findsNothing);
      expect(sensor.hasListener, isFalse);
    });

    testWidgets('does not combine partial jolts from before the app paused', (tester) async {
      bool captureStarted = false;
      await pumpApp(
        tester,
        captureScreenshot: () async {
          captureStarted = true;
          return null;
        },
      );
      sensor
        ..add(UserAccelerometerEvent(30, 0, 0, _at(0)))
        ..add(UserAccelerometerEvent(30, 0, 0, _at(200)));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleSensor(tester);
      sensor.add(UserAccelerometerEvent(30, 0, 0, _at(400)));
      await tester.pump();
      expect(captureStarted, isFalse);

      sensor
        ..add(UserAccelerometerEvent(30, 0, 0, _at(600)))
        ..add(UserAccelerometerEvent(30, 0, 0, _at(800)));
      await tester.pump();
      expect(captureStarted, isTrue);
    });

    testWidgets('does not open after the listener is disposed during capture', (tester) async {
      final Completer<Uint8List?> capture = Completer<Uint8List?>();
      final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester, captureScreenshot: () => capture.future);

      await startShake(tester, 0);
      await pumpApp(tester, navigatorKey: navigatorKey);
      capture.complete(null);
      await tester.pump();

      expect(find.text('Report a problem'), findsNothing);
    });

    testWidgets('a shake opens the report with a screenshot, and a shake while it is open does nothing', (
      tester,
    ) async {
      await pumpApp(tester);

      await shake(tester, 0);
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.byKey(const Key('report_problem_screenshot')), findsOneWidget);

      await shake(tester, 10000);
      expect(find.text('Report a problem'), findsOneWidget);
    });

    testWidgets('with the setting off, a shake does nothing', (tester) async {
      ShakeToReport.enabled.value = false;
      await pumpApp(tester);

      await shake(tester, 0);

      expect(sensor.hasListener, isFalse);
      expect(find.text('Report a problem'), findsNothing);
    });

    testWidgets('in the background it stops listening, and listens again on resume', (tester) async {
      await pumpApp(tester);
      expect(sensor.hasListener, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(sensor.hasListener, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleSensor(tester);
      expect(sensor.hasListener, isTrue);
    });

    testWidgets('a completed sensor stream can be subscribed again on resume', (tester) async {
      await pumpApp(tester);
      await sensor.close();
      await tester.pump();
      expect(sensor.hasListener, isFalse);

      sensor = StreamController<UserAccelerometerEvent>.broadcast();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleSensor(tester);

      expect(sensor.hasListener, isTrue);
    });

    testWidgets('a sensor stream error can be retried by toggling the setting', (tester) async {
      await pumpApp(tester);
      sensor.addError(StateError('sensor failed'));
      await tester.pump();
      expect(sensor.hasListener, isFalse);

      ShakeToReport.enabled.value = false;
      ShakeToReport.enabled.value = true;
      await settleSensor(tester);

      expect(sensor.hasListener, isTrue);
    });

    testWidgets('a synchronous sensor factory failure does not crash the app and can retry on resume', (tester) async {
      bool firstCall = true;
      await pumpApp(
        tester,
        accelerometer: () {
          if (firstCall) {
            firstCall = false;
            throw StateError('sensor unavailable');
          }
          return sensor.stream;
        },
      );

      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(sensor.hasListener, isTrue);
    });

    testWidgets('disposing the listener cancels its sensor subscription', (tester) async {
      final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester);
      expect(sensor.hasListener, isTrue);

      await pumpBareApp(tester, navigatorKey);

      expect(sensor.hasListener, isFalse);
    });

    testWidgets('a pending capture cannot open a sheet after listener removal', (tester) async {
      final Completer<Uint8List?> capture = Completer<Uint8List?>();
      bool captureStarted = false;
      final GlobalKey<NavigatorState> navigatorKey = await pumpApp(
        tester,
        captureScreenshot: () {
          captureStarted = true;
          return capture.future;
        },
      );
      await startShake(tester, 0);
      expect(captureStarted, isTrue);

      await pumpBareApp(tester, navigatorKey);
      expect(navigatorKey.currentContext?.mounted, isTrue);
      await finishCapture(tester, capture);

      expect(find.text('Report a problem'), findsNothing);
    });
  });

  test('disposes the captured image when PNG encoding fails', () async {
    final _FakeImage image = _FakeImage();

    await expectLater(
      encodeAndDisposeScreenshotImage(image, encode: (_, _) async => throw StateError('encode failed')),
      throwsStateError,
    );

    expect(image.disposed, isTrue);
  });

  test('set applies and persists the user choice', () async {
    final bool previousValue = ShakeToReport.enabled.value;
    final _MemoryLocalStore store = _MemoryLocalStore();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(store));
    addTearDown(() async {
      await getIt.reset();
      ShakeToReport.enabled.value = previousValue;
    });

    await ShakeToReport.set(false);

    expect(ShakeToReport.enabled.value, isFalse);
    expect(store.values[PersistenceKeys.settings(ShakeToReport.settingsKey)], isFalse);
  });
}
