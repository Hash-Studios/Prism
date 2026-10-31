import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/features/daily_flow/views/daily_moment_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_daily_moment_repository.dart';

void main() {
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  for (final bool hasStreakReceipt in <bool>[true, false]) {
    testWidgets('base deep link records its selected step once per open with streak receipt $hasStreakReceipt', (
      tester,
    ) async {
      final analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      final repository = FakeDailyMomentRepository();
      if (!hasStreakReceipt) repository.pendingReceipt = null;

      Widget content() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: DailyMomentContent(repository: repository, deepLink: true)),
        ),
      );

      for (var open = 1; open <= 2; open++) {
        await tester.pumpWidget(content());
        await tester.pump();
        await tester.pump();
        expect(
          analytics.events
              .where((event) => event.eventName == 'daily_moment_deep_link_opened')
              .map((event) => event.toWireParameters()),
          <Map<String, Object?>>[
            for (var index = 0; index < open; index++) {'step': hasStreakReceipt && index == 0 ? 'streak' : 'chest'},
          ],
        );

        await tester.pumpWidget(content());
        repository.balance = 150;
        await tester.pump();
        await tester.tap(find.text(hasStreakReceipt && open == 1 ? 'Continue' : 'Open for 20 coins'));
        await tester.pump();
        await tester.pump();
        expect(analytics.events.where((event) => event.eventName == 'daily_moment_deep_link_opened'), hasLength(open));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  testWidgets('explicit deep link records its requested step once', (tester) async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: DailyMomentContent(
              repository: FakeDailyMomentRepository(),
              deepLink: true,
              requestedStep: DailyMomentStep.spin,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      analytics.events.where((event) => event.eventName == 'daily_moment_deep_link_opened').single.toWireParameters(),
      <String, Object?>{'step': 'spin'},
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
  for (final failChest in [false, true]) {
    testWidgets('all daily actions stay visible at 3x text with chest failure $failChest', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeDailyMomentRepository();
      if (failChest) repository.pendingChest = Completer<DailyChestResult>()..complete(const ChestFailed('offline'));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3), disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(body: DailyMomentContent(repository: repository)),
        ),
      );
      await tester.pump();
      repository.balance = 120;
      await tester.pump();
      await tester.pump();
      expect(find.text('Balance: 120 coins'), findsOneWidget);
      final labels = failChest
          ? ['Continue', 'Open for 20 coins', 'Try again']
          : ['Continue', 'Open for 20 coins', 'Continue', 'Take free spin', 'Continue', 'Done'];
      for (var index = 0; index < labels.length; index++) {
        final label = find.text(labels[index]);
        expect(label, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.overflow, TextOverflow.visible);
        expect(paragraph.maxLines, isNull);
        expect(tester.takeException(), isNull);
        if (index < labels.length - 1) {
          await tester.tap(label);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
