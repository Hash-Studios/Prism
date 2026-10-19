import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  late FakeAppAnalytics analytics;
  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

  Widget tile(WallpaperImpressionSession session) => WallpaperImpression(
    itemId: 'wall',
    provider: 'prism',
    surface: AnalyticsSurfaceValue.homeWallpaperGrid,
    source: 'test',
    index: 0,
    session: session,
    child: const SizedBox(width: 100, height: 100),
  );

  testWidgets('requires dwell and deduplicates recycled tiles until request reset', (tester) async {
    WallpaperImpressionSession session = WallpaperImpressionSession(requestId: 'first');
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Align(alignment: Alignment.topLeft, child: tile(session)),
      ),
    );
    await show();
    await tester.pump(const Duration(milliseconds: 300));
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), isEmpty);
    await tester.pumpAndSettle();
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await show();
    await tester.pumpAndSettle();
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), hasLength(1));
    session = WallpaperImpressionSession(requestId: 'refreshed');
    await show();
    await tester.pumpAndSettle();
    expect(analytics.events.whereType<WallpaperImpressionEvent>().last.requestId, 'refreshed');
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), hasLength(2));
  });

  testWidgets('nested offscreen tiles wait for ancestor scroll and reset dwell in background', (tester) async {
    final ScrollController vertical = ScrollController();
    final WallpaperImpressionSession session = WallpaperImpressionSession();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: SingleChildScrollView(
          controller: vertical,
          child: Column(
            children: [
              const SizedBox(height: 700),
              SizedBox(
                height: 100,
                child: ListView(scrollDirection: Axis.horizontal, children: [tile(session)]),
              ),
              const SizedBox(height: 700),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), isEmpty);
    vertical.jumpTo(700);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), isEmpty);
    await tester.pumpAndSettle();
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    vertical.dispose();
  });

  testWidgets('less than half visible and covered routes do not count; returning starts fresh dwell', (tester) async {
    final ScrollController scroll = ScrollController(initialScrollOffset: 60);
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    final WallpaperImpressionSession session = WallpaperImpressionSession();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        navigatorKey: navigator,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                Align(alignment: Alignment.topLeft, child: tile(session)),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), isEmpty);
    scroll.jumpTo(40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold())));
    await tester.pumpAndSettle();
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(analytics.events.whereType<WallpaperImpressionEvent>(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
}
