import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/daily_flow/views/daily_moment_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_daily_moment_repository.dart';

void main() {
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  testWidgets('full paid action wraps at three times text size with reduced motion', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeDailyMomentRepository();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(3), disableAnimations: true),
          child: Scaffold(
            body: DailyMomentContent(repository: repository, requestedStep: DailyMomentStep.chest),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final action = find.text('Open for 20 coins');
    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, greaterThan(60));
    expect(repository.calls, <String>['refresh']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
