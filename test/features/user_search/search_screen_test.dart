import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/pages/search_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockSearchDiscoveryBloc extends MockBloc<SearchDiscoveryEvent, SearchDiscoveryState>
    implements SearchDiscoveryBloc {}

class _MockWallpaperSearchService extends Mock implements WallpaperSearchService {}

FeedItemEntity _wallpaper(int index) => PexelsFeedItem(
  id: 'wall-$index',
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: 'wall-$index',
      source: WallpaperSource.pexels,
      fullUrl: '',
      thumbnailUrl: '',
      authorName: 'Author $index',
    ),
  ),
);

void main() {
  late _MockWallpaperSearchService service;
  late FakeAppAnalytics analytics;

  void stubDiscovery(SearchDiscoveryState state) {
    final bloc = _MockSearchDiscoveryBloc();
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<SearchDiscoveryState>.empty(), initialState: state);
    getIt.registerFactory<SearchDiscoveryBloc>(() => bloc);
  }

  setUp(() {
    service = _MockWallpaperSearchService();
    getIt.registerSingleton<WallpaperSearchService>(service);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    stubDiscovery(SearchDiscoveryState.initial());
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  testWidgets('idle: title, pill field, tag chips and the discovery sections', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Search wallpapers'), findsOneWidget);
    expect(find.widgetWithText(PrismChip, 'Anime'), findsOneWidget);
    expect(find.text('#Anime'), findsNothing);
    expect(find.text('Find creators'), findsOneWidget);
    expect(find.text('Trending now'), findsOneWidget);
    expect(find.text('Browse by category'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Search by colour'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Search by colour'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);
  });

  testWidgets('shows the trending skeleton while loading and an error with retry when it fails', (tester) async {
    await getIt.reset();
    getIt.registerSingleton<WallpaperSearchService>(service);
    stubDiscovery(
      SearchDiscoveryState.initial().copyWith(status: LoadStatus.failure, failure: const NetworkFailure('x')),
    );

    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, "Couldn't load trending"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('submitting shows the query, the results grid and tracks the search', (tester) async {
    when(() => service.search('anime')).thenAnswer(
      (_) async => (provider: SearchProviderValue.pexels, results: List<FeedItemEntity>.generate(4, _wallpaper)),
    );
    await pumpScreen(tester);

    await submit(tester, 'anime');
    expect(find.byType(LoadingCards), findsOneWidget);
    await tester.pump();
    await tester.pump();

    expect(find.text('Results for "anime"'), findsOneWidget);
    expect(find.byType(PrismWallTile), findsNWidgets(4));
    expect(find.text('Find creators'), findsNothing);
    expect(analytics.events.whereType<SearchSubmittedEvent>(), hasLength(1));
  });

  testWidgets('no results shows a calm empty state with a hint', (tester) async {
    when(
      () => service.search('zzz'),
    ).thenAnswer((_) async => (provider: SearchProviderValue.wallhaven, results: const <FeedItemEntity>[]));
    await pumpScreen(tester);

    await submit(tester, 'zzz');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No wallpapers found'), findsOneWidget);
    expect(find.text('Try a shorter or a different word.'), findsOneWidget);
  });

  testWidgets('a failed search shows an error and retries the same query', (tester) async {
    var calls = 0;
    when(() => service.search('anime')).thenAnswer((_) {
      calls++;
      return calls == 1
          ? Future<WallpaperSearchPage>.delayed(const Duration(milliseconds: 50), () => throw Exception('offline'))
          : Future<WallpaperSearchPage>.value((
              provider: SearchProviderValue.pexels,
              results: <FeedItemEntity>[_wallpaper(1)],
            ));
    });
    await pumpScreen(tester);

    await submit(tester, 'anime');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(GlintState, "Couldn't search wallpapers"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(PrismWallTile), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('the clear button empties the field and returns to discovery', (tester) async {
    when(
      () => service.search('anime'),
    ).thenAnswer((_) async => (provider: SearchProviderValue.pexels, results: <FeedItemEntity>[_wallpaper(1)]));
    await pumpScreen(tester);
    await submit(tester, 'anime');
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
      () => service.search('Anime'),
    ).thenAnswer((_) async => (provider: SearchProviderValue.wallhaven, results: <FeedItemEntity>[_wallpaper(1)]));
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(PrismChip, 'Anime'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Results for "Anime"'), findsOneWidget);
    verify(() => service.search('Anime')).called(1);
  });
}
