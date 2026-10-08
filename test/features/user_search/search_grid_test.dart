import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockWallpaperSearchService extends Mock implements WallpaperSearchService {}

class _MockStackRouter extends Mock implements StackRouter {}

FeedItemEntity _wallpaper(int index) {
  final id = 'wallpaper-$index';
  return PexelsFeedItem(
    id: id,
    wallpaper: PexelsWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.pexels,
        fullUrl: '',
        thumbnailUrl: '',
        authorName: 'Author $index',
      ),
    ),
  );
}

void main() {
  late _MockWallpaperSearchService search;

  setUp(() {
    registerFallbackValue(SearchProviderValue.pexels);
    registerFallbackValue(WallpaperDetailRoute());
    registerFallbackValue(const SearchFilters());
    search = _MockWallpaperSearchService();
    getIt.registerSingleton<WallpaperSearchService>(search);
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('keeps the last wallpaper and appends See more after 24 results', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(400, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: List<FeedItemEntity>.generate(24, _wallpaper),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Wallpaper by Author 23'), findsOneWidget);
    expect(find.byType(SeeMoreButton), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('does not show See more for an empty first page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchGrid(query: 'nothing', provider: SearchProviderValue.pexels, initialResults: <FeedItemEntity>[]),
        ),
      ),
    );

    expect(find.byType(SeeMoreButton), findsNothing);
  });

  testWidgets('a failed next page shows a retry footer and a tap asks for the page again', (tester) async {
    tester.view.physicalSize = const Size(400, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int calls = 0;
    when(
      () => search.fetchPage(
        any(),
        any(),
        refresh: any(named: 'refresh'),
        filters: any(named: 'filters'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return <FeedItemEntity>[_wallpaper(100)];
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: List<FeedItemEntity>.generate(24, _wallpaper),
          ),
        ),
      ),
    );
    await tester.tap(find.text('See more'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load more. Tap to retry"), findsOneWidget);

    await tester.tap(find.text("Couldn't load more. Tap to retry"));
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
    expect(find.text("Couldn't load more. Tap to retry"), findsNothing);
  });

  testWidgets('shows the From Prism row above the provider results', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: <FeedItemEntity>[_wallpaper(1)],
            prismResults: <FeedItemEntity>[_wallpaper(2)],
          ),
        ),
      ),
    );

    expect(find.text('From Prism'), findsOneWidget);
  });

  testWidgets('a Prism-only page never asks the external providers for more or a refresh', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.prism,
            initialResults: const <FeedItemEntity>[],
            prismResults: <FeedItemEntity>[_wallpaper(2)],
          ),
        ),
      ),
    );

    expect(find.text('From Prism'), findsOneWidget);
    await tester.drag(find.text('From Prism'), const Offset(0, -400));
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.text('From Prism'), const Offset(0, 400));
    await tester.pump(const Duration(seconds: 1));

    verifyNever(
      () => search.fetchPage(
        any(),
        any(),
        refresh: any(named: 'refresh'),
        filters: any(named: 'filters'),
      ),
    );
  });

  testWidgets('a From Prism tile reports the Prism provider and its real index, and opens with a hero tag', (
    tester,
  ) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    final List<FeedItemEntity> prism = <FeedItemEntity>[_wallpaper(10), _wallpaper(11)];

    await tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: Scaffold(
            body: SearchGrid(
              query: 'landscape',
              provider: SearchProviderValue.pexels,
              initialResults: <FeedItemEntity>[_wallpaper(1)],
              prismResults: prism,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell).at(1));
    await tester.pump();

    final SearchResultOpenedEvent event = analytics.events.whereType<SearchResultOpenedEvent>().single;
    expect(event.provider, SearchProviderValue.prism);
    expect(event.index, 1);
    expect(event.itemId, 'wallpaper-11');
    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    expect(route.args!.heroTag, isNotNull);
    expect(route.args!.heroTag, contains('wallpaper-11'));
  });
}
