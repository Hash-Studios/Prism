import 'dart:async';
import 'dart:io' show SocketException;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/favourite_test_scope.dart';

class _MockWallpaperSearchService extends Mock implements WallpaperSearchService {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

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
  setUpFavouriteCounts();
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
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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
    expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    expect(find.byTooltip('Favourite'), findsWidgets);
    expect(find.byType(SeeMoreButton), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('prefetches the thumbnails below the first screen, up to 24', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _MockCacheManager cache = _MockCacheManager();
    PrismImageCache.testOverride = cache;
    addTearDown(() {
      PrismImageCache.testOverride = null;
      PaintingBinding.instance.imageCache.clear();
    });
    final List<String> fetched = <String>[];
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((invocation) {
      fetched.add(invocation.positionalArguments.first as String);
      return Stream<FileResponse>.error(const SocketException('offline'));
    });
    FeedItemEntity withThumb(int i) => PexelsFeedItem(
      id: 'w$i',
      wallpaper: PexelsWallpaper(
        core: WallpaperCore(
          id: 'w$i',
          source: WallpaperSource.pexels,
          fullUrl: '',
          thumbnailUrl: 'https://example.com/w$i-thumb.jpg',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: List<FeedItemEntity>.generate(40, withThumb),
          ),
        ),
      ),
    );
    for (int i = 0; i < 12; i++) {
      await tester.pump();
    }

    // 3 columns on a 400 x 800 screen: 9 tiles are on the first screen, so the prefetch ends at tile 9 + 24 - 1.
    expect(fetched, contains('https://example.com/w32-thumb.jpg'));
    expect(fetched, isNot(contains('https://example.com/w33-thumb.jpg')));
  });

  testWidgets('does not show See more for an empty first page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(query: 'nothing', provider: SearchProviderValue.pexels, initialResults: <FeedItemEntity>[]),
        ),
      ),
    );

    expect(find.byType(SeeMoreButton), findsNothing);
  });

  testWidgets('a refresh discards the older in-flight pagination response', (tester) async {
    tester.view.physicalSize = const Size(400, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Completer<List<FeedItemEntity>> nextPage = Completer<List<FeedItemEntity>>();
    when(
      () => search.fetchPage(SearchProviderValue.pexels, 'landscape', refresh: false, filters: any(named: 'filters')),
    ).thenAnswer((_) => nextPage.future);
    when(
      () => search.fetchPage(SearchProviderValue.pexels, 'landscape', refresh: true, filters: any(named: 'filters')),
    ).thenAnswer((_) async => <FeedItemEntity>[_wallpaper(100)]);
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            searchId: 'search',
            provider: SearchProviderValue.pexels,
            initialResults: List<FeedItemEntity>.generate(24, _wallpaper),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(SeeMoreButton));
    await tester.pump();
    await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    nextPage.complete(<FeedItemEntity>[_wallpaper(200)]);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Wallpaper by Author 100'), findsOneWidget);
    expect(find.bySemanticsLabel('Wallpaper by Author 200'), findsNothing);
    final FakeAppAnalytics recorder = AnalyticsRuntime.changes.value as FakeAppAnalytics;
    final cancelled = recorder.events.whereType<SearchResultsLoadedEvent>().where((event) => event.page == 2).single;
    expect(cancelled.result, EventResultValue.cancelled);
    expect(cancelled.resultCount, 0);
  });

  testWidgets('failed refresh retains impression deduplication for the same search request', (tester) async {
    when(
      () => search.fetchPage(SearchProviderValue.pexels, 'landscape', refresh: true, filters: any(named: 'filters')),
    ).thenThrow(StateError('offline'));
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            searchId: 'same-search',
            provider: SearchProviderValue.pexels,
            initialResults: <FeedItemEntity>[_wallpaper(1)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final FakeAppAnalytics recorder = AnalyticsRuntime.changes.value as FakeAppAnalytics;
    expect(recorder.events.whereType<WallpaperImpressionEvent>(), hasLength(1));
    await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pumpAndSettle();
    final List<WallpaperImpressionEvent> impressions = recorder.events.whereType<WallpaperImpressionEvent>().toList();
    expect(impressions, hasLength(1));
    expect(impressions.single.requestId, 'same-search');
  });

  testWidgets('labels local search results and does not offer remote pagination', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(
            query: 'forest',
            provider: SearchProviderValue.wallhaven,
            initialResults: <FeedItemEntity>[_wallpaper(0)],
            isLocal: true,
          ),
        ),
      ),
    );

    expect(find.text('Saved on this device'), findsOneWidget);
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
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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

  testWidgets('initial, paginated and refreshed counts include the Prism row', (tester) async {
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(
      () => search.fetchPage(SearchProviderValue.pexels, 'landscape', refresh: false, filters: any(named: 'filters')),
    ).thenAnswer((_) async => <FeedItemEntity>[_wallpaper(100)]);
    when(
      () => search.fetchPage(SearchProviderValue.pexels, 'landscape', refresh: true, filters: any(named: 'filters')),
    ).thenAnswer((_) async => <FeedItemEntity>[_wallpaper(200), _wallpaper(201)]);
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: List<FeedItemEntity>.generate(24, _wallpaper),
            prismResults: <FeedItemEntity>[_wallpaper(50)],
          ),
        ),
      ),
    );
    final recorder = AnalyticsRuntime.changes.value as FakeAppAnalytics;
    expect(recorder.events.whereType<SearchResultsLoadedEvent>().single.resultCount, 25);

    await tester.tap(find.byType(SeeMoreButton));
    await tester.pump();
    expect(recorder.events.whereType<SearchResultsLoadedEvent>().last.resultCount, 26);
    expect(recorder.events.whereType<SearchResultsLoadedEvent>().last.page, 2);

    await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    final loaded = recorder.events.whereType<SearchResultsLoadedEvent>().last;
    expect(loaded.resultCount, 3);
    expect(loaded.page, 1);
    expect(loaded.result, EventResultValue.success);
  });

  testWidgets('a Prism-only page never asks the external providers for more or a refresh', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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

    final recorder = AnalyticsRuntime.changes.value as FakeAppAnalytics;
    final loaded = recorder.events.whereType<SearchResultsLoadedEvent>().single;
    expect(loaded.resultCount, 1);
    expect(loaded.result, EventResultValue.success);
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
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: Scaffold(
            body: SearchGrid(
              query: 'landscape',
              provider: SearchProviderValue.pexels,
              initialResults: <FeedItemEntity>[_wallpaper(1)],
              prismResults: prism,
              searchId: 'search-request',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PrismWallTile).at(1));
    await tester.pump();

    final SearchResultOpenedEvent event = analytics.events.whereType<SearchResultOpenedEvent>().single;
    expect(event.provider, SearchProviderValue.prism);
    expect(event.index, 1);
    expect(event.itemId, 'wallpaper-11');
    expect(event.searchId, 'search-request');
    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    expect(route.args!.heroTag, isNotNull);
    expect(route.args!.heroTag, contains('wallpaper-11'));
    expect(route.args!.requestId, event.searchId);
  });

  testWidgets('swiping the From Prism row sideways never asks for the next results page', (tester) async {
    when(
      () => search.fetchPage(
        any(),
        any(),
        refresh: any(named: 'refresh'),
        filters: any(named: 'filters'),
      ),
    ).thenAnswer((_) async => <FeedItemEntity>[_wallpaper(99)]);

    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: List<FeedItemEntity>.generate(24, _wallpaper),
            prismResults: List<FeedItemEntity>.generate(12, (index) => _wallpaper(100 + index)),
          ),
        ),
      ),
    );
    final Finder row = find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    expect(row, findsOneWidget);

    await tester.drag(row, const Offset(-300, 0));
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

  testWidgets('scrolling the results down still asks for the next page', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(
      () => search.fetchPage(
        any(),
        any(),
        refresh: any(named: 'refresh'),
        filters: any(named: 'filters'),
      ),
    ).thenAnswer((_) async => <FeedItemEntity>[_wallpaper(99)]);

    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: List<FeedItemEntity>.generate(30, _wallpaper),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();
    await tester.pump();

    verify(
      () => search.fetchPage(
        any(),
        any(),
        refresh: any(named: 'refresh'),
        filters: any(named: 'filters'),
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('a loaded grid runs no skeleton ticker behind it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: List<FeedItemEntity>.generate(4, _wallpaper),
            prismResults: <FeedItemEntity>[_wallpaper(50)],
          ),
        ),
      ),
    );

    expect(find.byType(PulsePlaceholder), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('tiles fall back to the full wallpaper when the thumbnail fails', (tester) async {
    const FeedItemEntity withFull = PexelsFeedItem(
      id: 'p1',
      wallpaper: PexelsWallpaper(
        core: WallpaperCore(
          id: 'p1',
          source: WallpaperSource.pexels,
          fullUrl: 'https://example.test/full.jpg',
          thumbnailUrl: '',
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: <FeedItemEntity>[withFull],
            prismResults: <FeedItemEntity>[withFull],
          ),
        ),
      ),
    );

    final Iterable<PrismImageTile> tiles = tester.widgetList<PrismImageTile>(find.byType(PrismImageTile));
    expect(tiles, hasLength(2));
    expect(tiles.every((tile) => tile.fallbackUrl == 'https://example.test/full.jpg'), isTrue);
    expect(
      find.descendant(of: find.byType(PrismWallTile), matching: find.byType(PrismImageTile)),
      findsNWidgets(2),
      reason: 'the image sits inside the tile, so its Retry image button receives taps',
    );
  });

  testWidgets('holding a search wallpaper offers quick actions and release outside cancels', (tester) async {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));

    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SearchGrid(
            query: 'landscape',
            provider: SearchProviderValue.pexels,
            initialResults: <FeedItemEntity>[_wallpaper(1)],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PrismWallTile).first));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.bySemanticsLabel('Share link'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    expect(find.text('Show less like this'), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(find.bySemanticsLabel('Share link'), findsNothing);
  });
}
