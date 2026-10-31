import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_feed_settings.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/pages/search_screen.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/favourite_test_scope.dart';
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

FeedItemEntity _aiWallpaper(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
    isAiGenerated: true,
  ),
);

WallpaperSearchPage _page(
  List<FeedItemEntity> results, {
  SearchProviderValue provider = SearchProviderValue.wallhaven,
  List<FeedItemEntity> prismResults = const <FeedItemEntity>[],
  bool isLocal = false,
}) => (provider: provider, results: results, prismResults: prismResults, isLocal: isLocal);

void main() {
  setUpFavouriteCounts();
  late _MockWallpaperSearchService service;
  late InMemoryLocalStore store;
  late FakeAppAnalytics analytics;
  late _MockSearchDiscoveryBloc discoveryBloc;

  setUpAll(() => registerFallbackValue(const SearchFilters()));

  void stubDiscovery(SearchDiscoveryState state) {
    discoveryBloc = _MockSearchDiscoveryBloc();
    when(() => discoveryBloc.state).thenReturn(state);
    whenListen(discoveryBloc, const Stream<SearchDiscoveryState>.empty(), initialState: state);
    getIt.registerFactory<SearchDiscoveryBloc>(() => discoveryBloc);
  }

  setUp(() {
    service = _MockWallpaperSearchService();
    store = InMemoryLocalStore();
    getIt
      ..registerSingleton<WallpaperSearchService>(service)
      ..registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(store));
    stubDiscovery(SearchDiscoveryState.initial());
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchScreen(),
      ),
    );
    await tester.pump();
  }

  Future<void> enterQuery(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester, String query) async {
    await tester.pumpWidget(
      const MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchScreen(),
      ),
    );
    await enterQuery(tester, query);
  }

  testWidgets('idle: title, pill field, tag chips and the discovery sections', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Search wallpapers'), findsOneWidget);
    expect(find.widgetWithText(PrismChip, 'Nature'), findsOneWidget);
    expect(find.text('#Nature'), findsNothing);
    expect(find.text('Find creators'), findsOneWidget);
    expect(find.text('Trending now'), findsOneWidget);
    expect(find.text('Browse by category'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Browse by colour'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Browse by colour'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);
  });

  testWidgets('shows the trending skeleton while loading and an error with retry when it fails', (tester) async {
    await getIt.unregister<SearchDiscoveryBloc>();
    stubDiscovery(
      SearchDiscoveryState.initial().copyWith(status: LoadStatus.failure, failure: const NetworkFailure('x')),
    );

    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, "Couldn't load trending"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('submitting shows the query, the results grid and tracks the search', (tester) async {
    when(() => service.search('anime', filters: any(named: 'filters'))).thenAnswer(
      (_) async =>
          _page(List<FeedItemEntity>.generate(4, (i) => _wallpaper('wall-$i')), provider: SearchProviderValue.pexels),
    );
    await pumpScreen(tester);

    await enterQuery(tester, 'anime');
    expect(find.byType(LoadingCards), findsOneWidget);
    await tester.pump();
    await tester.pump();

    expect(find.text(AppLocalizationsEn().accountResultsForQuery('anime')), findsOneWidget);
    expect(find.byType(PrismWallTile), findsNWidgets(4));
    expect(find.text('Find creators'), findsNothing);
    expect(analytics.events.whereType<SearchSubmittedEvent>(), hasLength(1));
  });

  testWidgets('no results shows a calm empty state with a hint', (tester) async {
    when(() => service.search('zzz', filters: any(named: 'filters'))).thenAnswer((_) async => _page(const []));
    await pumpScreen(tester);

    await enterQuery(tester, 'zzz');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(AppLocalizationsEn().accountNoWallpapersFoundForQuery('zzz')), findsOneWidget);
    expect(find.text("Can't find it?"), findsOneWidget);
    expect(find.text('Request it'), findsOneWidget);
  });

  testWidgets('a failed search shows an error and retries the same query', (tester) async {
    var calls = 0;
    when(() => service.search('anime', filters: any(named: 'filters'))).thenAnswer((_) {
      calls++;
      return calls == 1
          ? Future<WallpaperSearchPage>.delayed(const Duration(milliseconds: 50), () => throw Exception('offline'))
          : Future<WallpaperSearchPage>.value(
              _page(<FeedItemEntity>[_wallpaper('wall-1')], provider: SearchProviderValue.pexels),
            );
    });
    await pumpScreen(tester);

    await enterQuery(tester, 'anime');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(GlintState, "Couldn't search right now"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(PrismWallTile), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('the clear button empties the field and returns to discovery', (tester) async {
    when(
      () => service.search('anime', filters: any(named: 'filters')),
    ).thenAnswer((_) async => _page(<FeedItemEntity>[_wallpaper('wall-1')], provider: SearchProviderValue.pexels));
    await pumpScreen(tester);
    await enterQuery(tester, 'anime');
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('Find creators'), findsOneWidget);
    expect(find.byType(PrismWallTile), findsNothing);
  });

  testWidgets('tapping a tag runs that search', (tester) async {
    when(
      () => service.search('Nature', filters: any(named: 'filters')),
    ).thenAnswer((_) async => _page(<FeedItemEntity>[_wallpaper('wall-1')]));
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(PrismChip, 'Nature'));
    await tester.pump();
    await tester.pump();

    expect(find.text(AppLocalizationsEn().accountResultsForQuery('Nature')), findsOneWidget);
    verify(() => service.search('Nature', filters: any(named: 'filters'))).called(1);
  });

  testWidgets('a search failure shows an error with Try again, not "No wallpapers found"', (tester) async {
    when(
      () => service.search(any(), filters: any(named: 'filters')),
    ).thenAnswer((_) => Future<WallpaperSearchPage>.error(const WallpaperSearchException('down')));

    await submit(tester, 'forest');
    await tester.pump();

    expect(find.text("Couldn't search right now"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('No wallpapers found'), findsNothing);
    expect(find.byType(LoadingCards), findsNothing);
  });

  testWidgets('a successful empty search shows the empty state', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: const <FeedItemEntity>[],
        prismResults: const <FeedItemEntity>[],
        isLocal: false,
      ),
    );

    await submit(tester, 'zzzz');
    await tester.pump();

    expect(find.text(AppLocalizationsEn().accountNoWallpapersFoundForQuery('zzzz')), findsOneWidget);
    expect(find.text("Couldn't search right now"), findsNothing);
  });

  testWidgets('a settings change reruns an empty search that was captured while AI was hidden', (tester) async {
    final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
    await settings.set('showAiWallpapers', false);
    int calls = 0;
    when(() => service.search('ai', filters: any(named: 'filters'))).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? _page(const <FeedItemEntity>[], provider: SearchProviderValue.prism)
          : _page(
              const <FeedItemEntity>[],
              provider: SearchProviderValue.prism,
              prismResults: <FeedItemEntity>[_aiWallpaper('ai-result')],
            );
    });

    await submit(tester, 'ai');
    await tester.pump();
    expect(find.byType(GlintState), findsOneWidget);
    expect(calls, 1);

    await setShowAiWallpapers(settings, true);
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(const ValueKey<String>('prism-ai-result')), findsOneWidget);
  });

  testWidgets('shows a From Prism row before the provider results', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallpaper('wh-1')],
        prismResults: <FeedItemEntity>[_wallpaper('prism-1')],
        isLocal: false,
      ),
    );

    await submit(tester, 'forest');
    await tester.pump();

    expect(find.byType(SearchGrid), findsOneWidget);
    expect(find.text('From Prism'), findsOneWidget);
    final loaded = analytics.events.whereType<SearchResultsLoadedEvent>().single;
    expect(loaded.resultCount, 2);
    expect(loaded.result, EventResultValue.success);
  });

  testWidgets('a Prism-only search reports its displayed row as a successful result', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => _page(
        const <FeedItemEntity>[],
        provider: SearchProviderValue.prism,
        prismResults: <FeedItemEntity>[_wallpaper('prism-1')],
      ),
    );

    await submit(tester, 'forest');
    await tester.pump();

    expect(find.text('From Prism'), findsOneWidget);
    final loaded = analytics.events.whereType<SearchResultsLoadedEvent>().single;
    expect(loaded.resultCount, 1);
    expect(loaded.result, EventResultValue.success);
  });

  testWidgets('a search is saved as a recent search and listed after the clear button is used', (tester) async {
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallpaper('wh-1')],
        prismResults: const <FeedItemEntity>[],
        isLocal: false,
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
        isLocal: false,
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
        isLocal: false,
      ),
    );
    pendingTagSearch.value = 'mountains';
    addTearDown(() => pendingTagSearch.value = null);

    await tester.pumpWidget(
      const MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchScreen(),
      ),
    );
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
        isLocal: false,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchScreen(),
      ),
    );

    pendingTagSearch.value = 'ocean';
    await tester.pump();
    await tester.pump();

    verify(() => service.search('ocean', filters: any(named: 'filters'))).called(1);
    expect(pendingTagSearch.value, isNull);
  });

  testWidgets('submission and results share an opaque ID across provider fallback', (tester) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.pexels,
        results: <FeedItemEntity>[_wallpaper('px-1')],
        prismResults: const <FeedItemEntity>[],
        isLocal: false,
      ),
    );

    await submit(tester, 'forest');
    await tester.pump();

    final SearchSubmittedEvent event = analytics.events.whereType<SearchSubmittedEvent>().single;
    expect(event.provider, SearchProviderValue.auto);
    expect(event.sourceContext, 'search_textfield');
    final SearchResultsLoadedEvent loaded = analytics.events.whereType<SearchResultsLoadedEvent>().single;
    expect(loaded.provider, SearchProviderValue.pexels);
    expect(loaded.searchId, event.searchId);
    expect(event.searchId, isNotEmpty);
    expect(event.toWireParameters().values, isNot(contains('forest')));
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
        isLocal: false,
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
      isLocal: false,
    ));
    await tester.pump();
    await tester.pump();

    final SearchGrid grid = tester.widget<SearchGrid>(find.byType(SearchGrid));
    expect(grid.initialResults.single.id, 'filtered-1');
  });

  testWidgets('the tag row lists the classifier names in the same order every time the screen opens', (tester) async {
    Future<List<String>> openTags() async {
      await tester.pumpWidget(
        MaterialApp(
          builder: favouriteTestBuilder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          key: UniqueKey(),
          home: const SearchScreen(),
        ),
      );
      final Iterable<Text> labels = tester.widgetList<Text>(
        find.descendant(of: find.byType(PrismChip), matching: find.byType(Text)),
      );
      return labels.take(3).map((text) => text.data!).toList();
    }

    final List<String> first = await openTags();
    final List<String> second = await openTags();

    expect(first, <String>['Nature', 'Architecture', 'Cars']);
    expect(second, first);
  });

  testWidgets('one discovery bloc serves the screen, so returning from a search does not reload trending', (
    tester,
  ) async {
    int created = 0;
    final discovery = _MockSearchDiscoveryBloc();
    when(() => discovery.state).thenReturn(SearchDiscoveryState.initial());
    await getIt.unregister<SearchDiscoveryBloc>();
    getIt.registerFactory<SearchDiscoveryBloc>(() {
      created++;
      return discovery;
    });
    when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
      (_) async => (
        provider: SearchProviderValue.wallhaven,
        results: <FeedItemEntity>[_wallpaper('wh-1')],
        prismResults: const <FeedItemEntity>[],
        isLocal: false,
      ),
    );

    await submit(tester, 'forest');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    expect(created, 1);
    verify(() => discovery.close()).called(1);
  });

  group('colour search', () {
    final SearchFilters red = SearchFilters(color: paletteColorById('red'));

    void answerWith(List<FeedItemEntity> results) {
      when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
        (_) async => (
          provider: SearchProviderValue.wallhaven,
          results: results,
          prismResults: const <FeedItemEntity>[],
          isLocal: false,
        ),
      );
    }

    Future<void> tapSwatch(WidgetTester tester, String name) async {
      await tester.pumpWidget(
        const MaterialApp(
          builder: favouriteTestBuilder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SearchScreen(),
        ),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(name));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a Browse by colour swatch searches that colour with an empty query', (tester) async {
      answerWith(<FeedItemEntity>[_wallpaper('wh-1')]);

      await tapSwatch(tester, 'Red');

      verify(() => service.search('', filters: red)).called(1);
      expect(find.byType(SearchGrid), findsOneWidget);
      expect(find.widgetWithText(PrismChip, 'Red'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('a colour search reports the colour_search quest event, a text search does not', (tester) async {
      final CoinsTestBackend backend = CoinsTestBackend();
      await backend.install();
      addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
      final List<String> events = <String>[];
      backend.onCall = (String name, Map<String, dynamic> params) async {
        if (name == 'progressQuest') events.add(params['event'] as String);
        return <String, Object?>{'success': true, 'rev': 1};
      };
      answerWith(<FeedItemEntity>[_wallpaper('wh-1')]);

      await submit(tester, 'forest');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(events, isEmpty);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Red'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));

      expect(events, <String>['colour_search']);
    });

    testWidgets('a colour-only search is not saved as a recent search', (tester) async {
      answerWith(<FeedItemEntity>[_wallpaper('wh-1')]);

      await tapSwatch(tester, 'Red');

      expect(store.data.keys.where((key) => key.contains('search.recent')), isEmpty);
    });

    testWidgets('an empty colour-only search says which colour had no wallpapers', (tester) async {
      answerWith(const <FeedItemEntity>[]);

      await tapSwatch(tester, 'Teal');

      expect(find.text(AppLocalizationsEn().accountNoWallpapersForFilters('teal')), findsOneWidget);
    });

    testWidgets('clearing the colour chip returns to discover', (tester) async {
      answerWith(<FeedItemEntity>[_wallpaper('wh-1')]);
      await tapSwatch(tester, 'Red');

      await tester.tap(find.byTooltip('Clear colour'));
      await tester.pump();

      expect(find.byType(SearchGrid), findsNothing);
      expect(find.text('Browse by colour'), findsOneWidget);
    });

    testWidgets('clearing the colour on a text search searches the text again without the colour', (tester) async {
      answerWith(<FeedItemEntity>[_wallpaper('wh-1')]);
      when(() => service.search('forest', filters: red)).thenAnswer(
        (_) async => (
          provider: SearchProviderValue.wallhaven,
          results: <FeedItemEntity>[_wallpaper('red-forest')],
          prismResults: const <FeedItemEntity>[],
          isLocal: false,
        ),
      );
      await submit(tester, 'forest');
      await tester.pump();
      await tester.tap(find.byTooltip('Filters'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.bySemanticsLabel('Red'));
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(tester.widget<SearchGrid>(find.byType(SearchGrid)).initialResults.single.id, 'red-forest');

      await tester.tap(find.byTooltip('Clear colour'));
      await tester.pump();
      await tester.pump();

      verify(() => service.search('forest')).called(2);
      expect(find.byTooltip('Clear colour'), findsNothing);
    });

    testWidgets('picking a colour in the filter sheet with an empty field runs a colour-only search', (tester) async {
      answerWith(<FeedItemEntity>[_wallpaper('wh-1')]);
      await tester.pumpWidget(
        const MaterialApp(
          builder: favouriteTestBuilder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SearchScreen(),
        ),
      );

      await tester.tap(find.byTooltip('Filters'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.descendant(of: find.byType(PrismSheetBody), matching: find.bySemanticsLabel('Red')));
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      verify(() => service.search('', filters: red)).called(1);
      expect(find.byType(SearchGrid), findsOneWidget);
    });

    testWidgets('going back from a colour-only search drops the colour', (tester) async {
      answerWith(<FeedItemEntity>[_wallpaper('wh-1')]);
      await tapSwatch(tester, 'Red');

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(SearchGrid), findsNothing);
      expect(find.text('Browse by colour'), findsOneWidget);
      final Badge badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isFalse);
    });

    testWidgets('an empty field and no colour does not search', (tester) async {
      answerWith(<FeedItemEntity>[_wallpaper('wh-1')]);
      await tester.pumpWidget(
        const MaterialApp(
          builder: favouriteTestBuilder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SearchScreen(),
        ),
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      verifyNever(() => service.search(any(), filters: any(named: 'filters')));
    });
  });

  group('Spatial Scene row', () {
    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('on ${platform.name} it lists Spatial walls with an empty query', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
            (_) async => _page(const <FeedItemEntity>[], prismResults: <FeedItemEntity>[_wallpaper('prism-1')]),
          );
          await pumpScreen(tester);

          await tester.tap(find.text('Spatial'));
          await tester.pump();
          await tester.pump();

          verify(() => service.search('', filters: const SearchFilters(spatialOnly: true))).called(1);
          expect(find.byType(SearchGrid), findsOneWidget);
          expect(find.byTooltip('Clear Spatial'), findsOneWidget);
          expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
          expect(analytics.events.whereType<SearchSubmittedEvent>().single.sourceContext, 'search_spatial');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  });

  group('Depth Effect row', () {
    testWidgets('on iOS it lists Depth Effect walls with an empty query', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        when(() => service.search(any(), filters: any(named: 'filters'))).thenAnswer(
          (_) async => _page(const <FeedItemEntity>[], prismResults: <FeedItemEntity>[_wallpaper('prism-1')]),
        );
        await pumpScreen(tester);

        await tester.tap(find.text('Depth Effect'));
        await tester.pump();
        await tester.pump();

        verify(() => service.search('', filters: const SearchFilters(depthOnly: true))).called(1);
        expect(find.byType(SearchGrid), findsOneWidget);
        expect(find.byTooltip('Clear Depth Effect'), findsOneWidget);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
        expect(analytics.events.whereType<SearchSubmittedEvent>().single.sourceContext, 'search_depth');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('off iOS the row is not shown', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Find creators'), findsOneWidget);
      expect(find.text('Depth Effect'), findsNothing);
    });
  });
}
