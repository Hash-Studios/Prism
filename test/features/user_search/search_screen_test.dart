import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/pages/search_screen.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _MockWallpaperSearchService extends Mock implements WallpaperSearchService {}

class _MockSearchDiscoveryBloc extends MockBloc<SearchDiscoveryEvent, SearchDiscoveryState>
    implements SearchDiscoveryBloc {}

FeedItemEntity _wallpaper(String id) => PexelsFeedItem(
  id: id,
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.pexels, fullUrl: '', thumbnailUrl: '', authorName: id),
  ),
);

void main() {
  late _MockWallpaperSearchService service;
  late InMemoryLocalStore store;

  setUpAll(() => registerFallbackValue(const SearchFilters()));

  setUp(() {
    service = _MockWallpaperSearchService();
    store = InMemoryLocalStore();
    final discovery = _MockSearchDiscoveryBloc();
    when(() => discovery.state).thenReturn(SearchDiscoveryState.initial());
    getIt
      ..registerSingleton<WallpaperSearchService>(service)
      ..registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(store))
      ..registerFactory<SearchDiscoveryBloc>(() => discovery);
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> submit(WidgetTester tester, String query) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  testWidgets('a search failure shows an error with Retry, not "No wallpapers found"', (tester) async {
    when(
      () => service.search(any(), filters: any(named: 'filters')),
    ).thenAnswer((_) => Future<WallpaperSearchPage>.error(const WallpaperSearchException('down')));

    await submit(tester, 'forest');
    await tester.pump();

    expect(find.text("Couldn't search right now"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('No wallpapers found'), findsNothing);
    expect(find.byType(LoadingCards), findsNothing);
  });

  testWidgets('Retry runs the same search again', (tester) async {
    when(
      () => service.search(any(), filters: any(named: 'filters')),
    ).thenAnswer((_) => Future<WallpaperSearchPage>.error(const WallpaperSearchException('down')));
    await submit(tester, 'forest');
    await tester.pump();

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => service.search('forest', filters: any(named: 'filters'))).called(2);
  });

  testWidgets('a successful empty search shows the empty state', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: const <FeedItemEntity>[],
        prismResults: const <FeedItemEntity>[],
      ),
    );

    await submit(tester, 'zzzz');
    await tester.pump();

    expect(find.text('No wallpapers found for "zzzz"'), findsOneWidget);
    expect(find.text("Couldn't search right now"), findsNothing);
  });

  testWidgets('shows a From Prism row before the provider results', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallpaper('wh-1')],
        prismResults: <FeedItemEntity>[_wallpaper('prism-1')],
      ),
    );

    await submit(tester, 'forest');
    await tester.pump();

    expect(find.byType(SearchGrid), findsOneWidget);
    expect(find.text('From Prism'), findsOneWidget);
  });

  testWidgets('a search is saved as a recent search and listed after the clear button is used', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallpaper('wh-1')],
        prismResults: const <FeedItemEntity>[],
      ),
    );
    await submit(tester, 'forest');
    await tester.pump();

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(find.byType(SearchGrid), findsNothing);
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('forest'), findsOneWidget);
  });

  testWidgets('system back from results returns to discover before leaving', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallpaper('wh-1')],
        prismResults: const <FeedItemEntity>[],
      ),
    );
    await submit(tester, 'forest');
    await tester.pump();
    expect(find.byType(SearchGrid), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byType(SearchGrid), findsNothing);
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('a tag chip search waiting when the screen opens runs at once and is cleared', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallpaper('wh-1')],
        prismResults: const <FeedItemEntity>[],
      ),
    );
    pendingTagSearch.value = 'mountains';
    addTearDown(() => pendingTagSearch.value = null);

    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pump();
    await tester.pump();

    verify(() => service.search('mountains', filters: any(named: 'filters'))).called(1);
    expect(pendingTagSearch.value, isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'mountains');
  });

  testWidgets('a tag chip search sent while the screen is open runs the search', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallpaper('wh-1')],
        prismResults: const <FeedItemEntity>[],
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));

    pendingTagSearch.value = 'ocean';
    await tester.pump();
    await tester.pump();

    verify(() => service.search('ocean', filters: any(named: 'filters'))).called(1);
    expect(pendingTagSearch.value, isNull);
  });

  testWidgets('the search event reports the provider that returned the results', (tester) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.pexels,
        results: <FeedItemEntity>[_wallpaper('px-1')],
        prismResults: const <FeedItemEntity>[],
      ),
    );

    await submit(tester, 'forest');
    await tester.pump();

    final SearchSubmittedEvent event = analytics.events.whereType<SearchSubmittedEvent>().single;
    expect(event.provider, SearchProviderValue.pexels);
    expect(event.sourceContext, 'search_textfield');
  });

  testWidgets('changing filters drops the old results while the new search runs', (tester) async {
    final Completer<WallpaperSearchPage> filtered = Completer<WallpaperSearchPage>();
    when(
      () => service.search(
        any(),
        filters: any(named: 'filters', that: equals(const SearchFilters())),
      ),
    ).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallpaper('unfiltered-1')],
        prismResults: const <FeedItemEntity>[],
      ),
    );
    when(
      () => service.search(any(), filters: const SearchFilters(minResolution: '1440x2560')),
    ).thenAnswer((_) => filtered.future);

    await submit(tester, 'forest');
    await tester.pump();
    expect(tester.widget<SearchGrid>(find.byType(SearchGrid)).initialResults.single.id, 'unfiltered-1');

    await tester.tap(find.byTooltip('Filters'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('1440p'));
    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SearchGrid), findsNothing);
    expect(find.byType(LoadingCards), findsOneWidget);

    filtered.complete((
      provider: SearchProviderValue.wallhaven,
      results: <FeedItemEntity>[_wallpaper('filtered-1')],
      prismResults: const <FeedItemEntity>[],
    ));
    await tester.pump();
    await tester.pump();

    final SearchGrid grid = tester.widget<SearchGrid>(find.byType(SearchGrid));
    expect(grid.initialResults.single.id, 'filtered-1');
  });
}
