import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

  List<String> requests() => analytics.events.whereType<WallpaperImpressionEvent>().map((e) => e.requestId).toList();

  Widget tile({WallpaperImpressionSession? session, VoidCallback? onVisible, String itemId = 'wall'}) =>
      WallpaperImpression(
        itemId: itemId,
        provider: 'prism',
        surface: AnalyticsSurfaceValue.homeWallpaperGrid,
        source: 'test',
        index: 2,
        session: session,
        onVisible: onVisible,
        child: const SizedBox(width: 100, height: 100),
      );

  Widget app(Widget child) => MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: child),
  );

  testWidgets('first-frame visible tile records at 500 ms exactly once with its payload', (tester) async {
    int visible = 0;
    await tester.pumpWidget(
      app(
        tile(
          session: WallpaperImpressionSession(requestId: 'first'),
          onVisible: () => visible++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 499));
    expect(requests(), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(requests(), <String>['first']);
    expect(visible, 1);
    final WallpaperImpressionEvent event = analytics.events.whereType<WallpaperImpressionEvent>().single;
    expect(event.toWireParameters(), <String, Object?>{
      'item_id': 'wall',
      'provider': 'prism',
      'surface': 'home_wallpaper_grid',
      'request_id': 'first',
      'index': 2,
      'source': 'test',
    });
    await tester.pump(const Duration(seconds: 1));
    expect(requests(), <String>['first']);
    expect(visible, 1);
  });

  testWidgets('a tile scrolled into view then left idle records after a fresh dwell', (tester) async {
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      app(
        SingleChildScrollView(
          controller: scroll,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 700),
              tile(session: WallpaperImpressionSession(requestId: 'scroll')),
              const SizedBox(height: 700),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(requests(), isEmpty);
    scroll.jumpTo(700);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(requests(), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(requests(), <String>['scroll']);
    scroll.jumpTo(0);
    await tester.pump();
    scroll.jumpTo(700);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(requests(), <String>['scroll']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('scrolling offscreen on the dwell deadline does not record stale geometry', (tester) async {
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      app(
        ListView(
          controller: scroll,
          children: <Widget>[
            tile(session: WallpaperImpressionSession(requestId: 'deadline')),
            const SizedBox(height: 1000),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    scroll.jumpTo(200);
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests(), isEmpty);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(requests(), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(requests(), <String>['deadline']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nested carousel requires visibility in both scroll viewports', (tester) async {
    final ScrollController vertical = ScrollController();
    final ScrollController horizontal = ScrollController();
    addTearDown(vertical.dispose);
    addTearDown(horizontal.dispose);
    await tester.pumpWidget(
      app(
        SingleChildScrollView(
          controller: vertical,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 700),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  controller: horizontal,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 900),
                      tile(session: WallpaperImpressionSession(requestId: 'nested')),
                      const SizedBox(width: 900),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 700),
            ],
          ),
        ),
      ),
    );
    vertical.jumpTo(700);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(requests(), isEmpty);
    horizontal.jumpTo(900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    vertical.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(requests(), isEmpty);
    vertical.jumpTo(700);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(requests(), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(requests(), <String>['nested']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an inherited refresh resets a recorded tile without recreating it', (tester) async {
    final Widget child = tile();
    Future<void> show(String request) => tester.pumpWidget(
      app(
        WallpaperImpressionScope(
          session: WallpaperImpressionSession(requestId: request),
          child: child,
        ),
      ),
    );
    await show('before');
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests(), <String>['before']);
    await show('after');
    await tester.pump(const Duration(milliseconds: 499));
    expect(requests(), <String>['before']);
    await tester.pump(const Duration(milliseconds: 1));
    expect(requests(), <String>['before', 'after']);
  });

  testWidgets('removing an explicit session uses the current inherited result set', (tester) async {
    final WallpaperImpressionSession explicit = WallpaperImpressionSession(requestId: 'explicit');
    final WallpaperImpressionSession inherited = WallpaperImpressionSession(requestId: 'inherited');
    Future<void> show(WallpaperImpressionSession? session) => tester.pumpWidget(
      app(
        WallpaperImpressionScope(
          session: inherited,
          child: tile(session: session),
        ),
      ),
    );
    await show(explicit);
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests(), <String>['explicit']);
    await show(null);
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests(), <String>['explicit', 'inherited']);
  });

  testWidgets('disposing a tile with a pending scroll check does not record or retain a ticker', (tester) async {
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    final WallpaperImpressionSession session = WallpaperImpressionSession(requestId: 'dispose');
    await tester.pumpWidget(
      app(
        SingleChildScrollView(
          controller: scroll,
          child: Column(
            children: <Widget>[
              tile(session: session),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    scroll.jumpTo(10);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(requests(), isEmpty);
    await tester.pumpWidget(app(tile(session: session)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests(), <String>['dispose']);
  });

  testWidgets('a recycled tile deduplicates the item but records a new item in the same session', (tester) async {
    final WallpaperImpressionSession session = WallpaperImpressionSession(requestId: 'retry');
    await tester.pumpWidget(app(tile(session: session)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(tile(session: session)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests(), <String>['retry']);
    await tester.pumpWidget(app(tile(session: session, itemId: 'second')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(analytics.events.whereType<WallpaperImpressionEvent>().map((e) => e.itemId), <String>['wall', 'second']);
  });
}
