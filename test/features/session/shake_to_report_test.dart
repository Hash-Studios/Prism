import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/session/data/shake_to_report.dart';
import 'package:Prism/features/session/views/widgets/shake_to_report_listener.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

DateTime _at(int ms) => DateTime.utc(2026).add(Duration(milliseconds: ms));

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

    Future<void> pumpApp(WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              ShakeToReportListener(navigatorKey: navigatorKey, accelerometer: () => sensor.stream, child: child!),
          home: const Scaffold(body: Text('home')),
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
      expect(sensor.hasListener, isTrue);
    });
  });
}
