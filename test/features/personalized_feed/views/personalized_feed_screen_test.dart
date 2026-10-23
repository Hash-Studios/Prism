import 'dart:async';
import 'dart:io' show SocketException;

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/domain/repositories/drops_repository.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/home_feed_tab_bar.dart';
import 'package:Prism/features/personalized_feed/views/widgets/paged_chip_sliver.dart';
import 'package:Prism/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/coins_test_backend.dart';
import '../../../support/fake_app_analytics.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/favourite_test_scope.dart';

class _MockFetchUseCase extends Mock implements FetchPersonalizedFeedUseCase {}

class _MockFeedRepository extends Mock implements PersonalizedFeedRepository {}

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockFetchTrending extends Mock implements FetchTrendingUseCase {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

class _MockFavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _MockPagedFeedBloc extends MockBloc<PagedFeedEvent, PagedFeedState> implements PagedFeedBloc {}

class _MockNotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

FeedItemEntity _item(String id, {List<String>? collections}) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', authorEmail: '$id@x.com'),
    collections: collections,
  ),
);

PrismWallpaper _wall(String id, {DateTime? boostedUntil}) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', authorEmail: '$id@x.com'),
  boostedUntil: boostedUntil,
);

PersonalizedFeedPage _page(
  List<String> ids, {
  bool hasMore = false,
  bool isStale = false,
  Set<String> premium = const <String>{},
}) => PersonalizedFeedPage(
  items: ids.map((id) => _item(id, collections: premium.contains(id) ? const <String>['space'] : null)).toList(),
  hasMore: hasMore,
  isStale: isStale,
  usedKeys: ids,
);

class _FakeDropsRepository implements DropsRepository {
  @override
  Future<Result<DropEntity?>> fetchLive(DateTime now) async => Result.success<DropEntity?>(null);

  @override
  Future<Result<DropEntity?>> fetchByWeekKey(String weekKey) async => Result.success<DropEntity?>(null);
}

void main() {
  setUpFavouriteCounts();
  List<String> recordHaptics(WidgetTester tester) {
    const MethodChannel channel = MethodChannel('prism/haptics');
    final bool wasEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    final List<String> events = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'play') events.add(call.arguments! as String);
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      PrismHaptics.enabled = wasEnabled;
    });
    return events;
  }

  late _MockFetchUseCase fetchUseCase;
  late _MockFeedRepository feedRepository;
  late _MockPrismRepository prismRepository;
  late _MockFetchTrending fetchTrending;
  late _MockCacheManager cache;

  setUpAll(() {
    registerFallbackValue(
      const FetchPersonalizedFeedRequest(
        page: 1,
        refresh: true,
        seenKeys: <String>[],
        existingItems: <FeedItemEntity>[],
      ),
    );
    registerFallbackValue(_item('fallback'));
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    fetchUseCase = _MockFetchUseCase();
    feedRepository = _MockFeedRepository();
    prismRepository = _MockPrismRepository();
    cache = _MockCacheManager();
    PrismImageCache.testOverride = cache;
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) => Stream<FileResponse>.error(const SocketException('offline')));
    when(() => feedRepository.readCached()).thenAnswer((_) async => null);
    when(() => feedRepository.recordShown(any())).thenAnswer((_) async {});
    when(() => feedRepository.lessLikeThis(any())).thenAnswer((_) async {});
    when(() => feedRepository.undoLessLikeThis(any())).thenAnswer((_) async {});
    when(
      () => feedRepository.fetchFollowing(page: any(named: 'page')),
    ).thenAnswer((_) async => Result.success(_page(<String>[])));
    when(() => feedRepository.fetchPopular()).thenAnswer((_) async => Result.success(_page(<String>['pop1', 'pop2'])));
    when(
      () => prismRepository.fetchFeed(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('late1')]));
    when(() => prismRepository.hasMore).thenReturn(false);
    when(
      () => fetchUseCase(any()),
    ).thenAnswer((_) async => Result.success(_page(<String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'], hasMore: true)));
    fetchTrending = _MockFetchTrending();
    when(() => fetchTrending(any())).thenAnswer((_) async => Result.success(<PrismWallpaper>[]));
    app_state.prismUser = _user(loggedIn: true);
    getIt
      ..registerFactory<PersonalizedFeedBloc>(
        () => PersonalizedFeedBloc(
          fetchUseCase,
          feedRepository,
          FakeUserBlockRepository.pending(),
          _FakeDropsRepository(),
        ),
      )
      ..registerFactory<LatestFeedBloc>(() => LatestFeedBloc(prismRepository))
      ..registerFactory<FollowingFeedBloc>(() => FollowingFeedBloc(feedRepository))
      ..registerFactory<PopularFeedBloc>(() => PopularFeedBloc(feedRepository))
      ..registerFactory<TrendingBloc>(() => TrendingBloc(fetchTrending, FakeUserBlockRepository.pending()))
      ..registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    PrismImageCache.testOverride = null;
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool disableAnimations = false,
    bool tickersEnabled = true,
    WallOfTheDayEntity? wotdEntity,
    VoidCallback? onTuneTap,
    Size viewSize = const Size(600, 3000),
    double statusBar = 0,
  }) async {
    // Tall by default, so the header, the carousel and the first rows of tiles are all on screen.
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: statusBar);
    tester.view.viewPadding = FakeViewPadding(top: statusBar);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final wotd = _MockWotdBloc();
    when(() => wotd.state).thenReturn(
      WotdState.initial().copyWith(
        status: wotdEntity == null ? LoadStatus.initial : LoadStatus.success,
        entity: wotdEntity,
      ),
    );
    final favourites = _MockFavouriteBloc();
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
    final notifications = _MockNotificationsBloc();
    when(() => notifications.state).thenReturn(InAppNotificationsState.initial());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: favouriteTestBuilder(context, child),
        ),
        home: Scaffold(
          body: TickerMode(
            enabled: tickersEnabled,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<WotdBloc>.value(value: wotd),
                BlocProvider<FavouriteWallsBloc>.value(value: favourites),
                BlocProvider<InAppNotificationsBloc>.value(value: notifications),
              ],
              child: PersonalizedFeedScreen(onTuneTap: onTuneTap),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  Finder tab(String label) => find.widgetWithText(Tab, label);

  /// The tabs scroll sideways when they are wider than the screen, so bring one into view before the tap.
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.ensureVisible(tab(label));
    await tester.pump();
    await tester.tap(tab(label));
  }

  PersonalizedFeedBloc feedBloc(WidgetTester tester) =>
      tester.element(find.byType(CustomScrollView)).read<PersonalizedFeedBloc>();

  testWidgets('shows the five tabs in the header, with For you chosen', (tester) async {
    await pumpScreen(tester);

    final List<String> labels = <String>['For you', 'Following', 'Trending', 'Latest', 'Popular'];
    final List<double> lefts = labels.map((label) => tester.getTopLeft(find.text(label)).dx).toList();
    expect(find.byType(Tab), findsNWidgets(5));
    expect(lefts, <double>[...lefts]..sort());
    expect(feedBloc(tester).state.chip, HomeFeedChip.forYou);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    expect(find.byType(WallpaperTile), findsWidgets);
  });

  testWidgets('tapping Latest selects it and the underline follows', (tester) async {
    await pumpScreen(tester);

    await tapTab(tester, 'Latest');
    await _settle(tester);

    expect(feedBloc(tester).state.chip, HomeFeedChip.latest);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 3);
  });

  testWidgets('the For you header has no section title and no tune button', (tester) async {
    var tuned = 0;
    await pumpScreen(tester, onTuneTap: () => tuned++);

    expect(find.text('For you'), findsOneWidget, reason: 'only the tab says it');
    expect(find.byTooltip('Tune your feed'), findsNothing);
    expect(find.text('Tune your feed'), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
    expect(tuned, 0);
  });

  testWidgets('tapping For you while it is chosen opens the feed settings once', (tester) async {
    var tuned = 0;
    await pumpScreen(tester, onTuneTap: () => tuned++);

    await tapTab(tester, 'For you');
    await _settle(tester);

    expect(tuned, 1);
    expect(feedBloc(tester).state.chip, HomeFeedChip.forYou);
  });

  testWidgets('tapping For you from another tab selects it and does not open the feed settings', (tester) async {
    var tuned = 0;
    await pumpScreen(tester, onTuneTap: () => tuned++);
    await tapTab(tester, 'Popular');
    await _settle(tester);

    await tapTab(tester, 'For you');
    await _settle(tester);

    expect(tuned, 0);
    expect(feedBloc(tester).state.chip, HomeFeedChip.forYou);
  });

  testWidgets('the carousel is For you content: the other tabs have none', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(FeedCarousel), findsOneWidget);

    await tapTab(tester, 'Latest');
    await _settle(tester);

    expect(find.byType(FeedCarousel), findsNothing);
  });

  testWidgets('the home loads the trending week list once at start, and has no Trending strip', (tester) async {
    await pumpScreen(tester);

    verify(() => fetchTrending(any())).called(1);
    expect(find.text('Trending this week'), findsNothing);
    expect(find.text('See all'), findsNothing);
  });

  testWidgets('the Trending tab shows the trending walls in the home grid, with no range switch', (tester) async {
    when(() => fetchTrending(any())).thenAnswer(
      (_) async => Result.success(<PrismWallpaper>[
        _wall('hot1', boostedUntil: DateTime.now().add(const Duration(hours: 3))),
        _wall('hot2'),
        _wall('hot3'),
        _wall('hot4'),
      ]),
    );
    await pumpScreen(tester);

    await tapTab(tester, 'Trending');
    await _settle(tester);

    verify(() => fetchTrending(any())).called(1);
    expect(find.text('This week'), findsNothing);
    expect(find.text('All time'), findsNothing);
    expect(find.byType(WallpaperTile), findsNWidgets(4));
    expect(find.text('Boosted'), findsOneWidget);
    expect(find.byType(FeedCarousel), findsNothing);
    final Rect first = tester.getRect(find.byType(WallpaperTile).first);
    final Rect second = tester.getRect(find.byType(WallpaperTile).at(1));
    expect(first.left, 4, reason: 'a 4 px side margin');
    expect(second.left - first.right, 4, reason: 'a 4 px gap');
  });

  testWidgets('an empty Trending tab says nothing is trending', (tester) async {
    await pumpScreen(tester);

    await tapTab(tester, 'Trending');
    await _settle(tester);

    expect(find.text('Nothing is trending yet'), findsOneWidget);
    expect(find.byType(WallpaperTile), findsNothing);
  });

  testWidgets('a failed Trending load offers Try again and loads again', (tester) async {
    int calls = 0;
    when(() => fetchTrending(any())).thenAnswer(
      (_) async => ++calls == 1
          ? Result.error(const NetworkFailure('offline'))
          : Result.success(<PrismWallpaper>[_wall('hot1')]),
    );
    await pumpScreen(tester);
    await tapTab(tester, 'Trending');
    await _settle(tester);
    expect(find.text("Couldn't load trending wallpapers"), findsOneWidget);

    await tester.tap(find.widgetWithText(PrismButton, 'Try again'));
    await _settle(tester);

    expect(find.text("Couldn't load trending wallpapers"), findsNothing);
    expect(find.byType(WallpaperTile), findsOneWidget);
  });

  testWidgets('pull to refresh on the Trending tab reloads the trending list and waits for it', (tester) async {
    await pumpScreen(tester);
    await tapTab(tester, 'Trending');
    await _settle(tester);
    verify(() => fetchTrending(any())).called(1);
    final Completer<Result<List<PrismWallpaper>>> pending = Completer<Result<List<PrismWallpaper>>>();
    when(() => fetchTrending(any())).thenAnswer((_) => pending.future);

    bool refreshed = false;
    final Future<void> refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh()
        .then((_) => refreshed = true);
    await tester.pump();

    verify(() => fetchTrending(any())).called(1);
    expect(refreshed, isFalse, reason: 'the spinner lasts as long as the load');

    pending.complete(Result.success(<PrismWallpaper>[_wall('hot1')]));
    await refresh;
    await tester.pump();

    expect(refreshed, isTrue);
  });

  testWidgets('pull to refresh on the Latest tab reloads Latest and not the trending list', (tester) async {
    await pumpScreen(tester);
    await tapTab(tester, 'Latest');
    await _settle(tester);
    verify(() => prismRepository.fetchFeed(refresh: true)).called(1);
    verify(() => fetchTrending(any())).called(1);

    await tester.drag(
      find.descendant(of: find.byType(RefreshIndicator), matching: find.byType(CustomScrollView)).first,
      const Offset(0, 1200),
    );
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(() => prismRepository.fetchFeed(refresh: true)).called(1);
    verifyNever(() => fetchTrending(any()));
  });

  testWidgets('pull to refresh on For you reloads the feed and the trending list that feeds the carousel', (
    tester,
  ) async {
    await pumpScreen(tester);
    verify(() => fetchTrending(any())).called(1);
    clearInteractions(fetchUseCase);

    await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await _settle(tester);

    verify(() => fetchUseCase(any())).called(1);
    verify(() => fetchTrending(any())).called(1);
  });

  testWidgets('refresh preserves impression dedupe while pending and failed, then resets on success', (tester) async {
    await pumpScreen(tester);
    WallpaperImpressionSession session() =>
        tester.widget<WallpaperImpressionScope>(find.byType(WallpaperImpressionScope).first).session;
    expect(session().record('prism', 'probe'), isTrue);
    final pending = Completer<Result<PersonalizedFeedPage>>();
    when(() => fetchUseCase(any())).thenAnswer((_) => pending.future);
    final Future<void> failedRefresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first).onRefresh();
    await tester.pump();
    expect(session().record('prism', 'probe'), isFalse);
    pending.complete(Result.error(const NetworkFailure('offline')));
    await tester.pump();
    await failedRefresh;
    await tester.pump();
    expect(session().record('prism', 'probe'), isFalse);
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(_page(<String>['a', 'b', 'c'])));
    final Future<void> successfulRefresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pump();
    await successfulRefresh;
    await tester.pump();
    expect(session().record('prism', 'probe'), isTrue);
  });

  testWidgets('the Latest tab loads the newest Prism walls', (tester) async {
    await pumpScreen(tester);
    verifyNever(() => prismRepository.fetchFeed(refresh: any(named: 'refresh')));

    await tapTab(tester, 'Latest');
    await _settle(tester);

    verify(() => prismRepository.fetchFeed(refresh: true)).called(1);
    expect(feedBloc(tester).state.chip, HomeFeedChip.latest);
    expect(find.byType(WallpaperTile), findsOneWidget);
  });

  testWidgets('the Popular tab shows the popular walls', (tester) async {
    await pumpScreen(tester);

    await tapTab(tester, 'Popular');
    await _settle(tester);

    verify(() => feedRepository.fetchPopular()).called(1);
    expect(find.byType(WallpaperTile), findsNWidgets(2));
  });

  testWidgets('a tab is loaded once, however often the user comes back to it', (tester) async {
    await pumpScreen(tester);

    for (final label in <String>['Popular', 'For you', 'Popular']) {
      await tapTab(tester, label);
      await _settle(tester);
    }

    verify(() => feedRepository.fetchPopular()).called(1);
  });

  testWidgets('the Trending tab reports the daily trending quest once a day', (tester) async {
    final CoinsTestBackend backend = CoinsTestBackend();
    final List<String> events = <String>[];
    await tester.runAsync(backend.install);
    backend.onCall = (String name, Map<String, dynamic> params) async {
      if (name == 'progressQuest') events.add(params['event'] as String);
      return <String, Object?>{
        'success': true,
        'rev': 1,
        'quests': <String, Object?>{'dayKey': economyDayKey(DateTime.now())},
      };
    };
    await pumpScreen(tester);

    for (final label in <String>['Trending', 'Latest', 'Trending']) {
      await tapTab(tester, label);
      await _settle(tester);
    }

    expect(events, <String>['view_trending']);
  });

  testWidgets('opening the home alone reports no trending quest, the Trending tab does', (tester) async {
    final CoinsTestBackend backend = CoinsTestBackend();
    final List<String> events = <String>[];
    await tester.runAsync(backend.install);
    backend.onCall = (String name, Map<String, dynamic> params) async {
      if (name == 'progressQuest') events.add(params['event'] as String);
      return <String, Object?>{
        'success': true,
        'rev': 1,
        'quests': <String, Object?>{'dayKey': economyDayKey(DateTime.now())},
      };
    };
    await pumpScreen(tester);

    expect(events, isEmpty);

    await tapTab(tester, 'Trending');
    await _settle(tester);

    expect(events, <String>['view_trending']);
  });

  testWidgets('Following with nobody followed explains how to fill it and offers a way to find creators', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapTab(tester, 'Following');
    await _settle(tester);

    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(find.text(l10n.wallpaperFeedFollowingEmptyTitle), findsOneWidget);
    expect(find.widgetWithText(PrismButton, l10n.accountFindCreators), findsOneWidget);
    expect(find.byType(WallpaperTile), findsNothing);
  });

  testWidgets('Following lists the followed creators walls', (tester) async {
    when(
      () => feedRepository.fetchFollowing(page: 1),
    ).thenAnswer((_) async => Result.success(_page(<String>['f1', 'f2', 'f3'])));
    await pumpScreen(tester);

    await tapTab(tester, 'Following');
    await _settle(tester);

    expect(find.byType(WallpaperTile), findsNWidgets(3));
  });

  testWidgets('a guest is asked to sign in on the Following tab and nothing is fetched', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await pumpScreen(tester);

    await tapTab(tester, 'Following');
    await _settle(tester);

    expect(find.text('Sign in to use Following'), findsOneWidget);
    verifyNever(() => feedRepository.fetchFollowing(page: any(named: 'page')));
  });

  testWidgets('a failed Latest load offers Try again', (tester) async {
    when(
      () => prismRepository.fetchFeed(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => Result.error(const NetworkFailure('x')));
    await pumpScreen(tester);

    await tapTab(tester, 'Latest');
    await _settle(tester);

    expect(find.text(AppLocalizationsEn().wallpaperFeedLatestLoadError), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Try again'), findsOneWidget);
  });

  testWidgets('cached walls show at once with an Updating bar, which goes when the fresh page lands', (tester) async {
    final Completer<Result<PersonalizedFeedPage>> fresh = Completer<Result<PersonalizedFeedPage>>();
    when(
      () => feedRepository.readCached(),
    ).thenAnswer((_) async => _page(<String>['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7']));
    when(() => fetchUseCase(any())).thenAnswer((_) => fresh.future);
    await pumpScreen(tester);

    expect(find.byType(WallpaperTile), findsWidgets);
    final Finder updating = find.bySemanticsLabel('Updating');
    expect(
      find.descendant(of: find.byType(HomeFeedTabBar), matching: find.byType(LinearProgressIndicator)),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(updating, findsOneWidget);

    fresh.complete(Result.success(_page(<String>['n1', 'n2', 'n3', 'n4', 'n5', 'n6', 'n7'])));
    await _settle(tester);

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Show less like this gives an Undo that brings the wallpaper back', (tester) async {
    await pumpScreen(tester);
    final int before = find.byType(WallpaperTile).evaluate().length;
    final gesture = await tester.startGesture(tester.getCenter(find.byType(WallpaperTile).first));
    await tester.pump(const Duration(milliseconds: 600));
    await _settle(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Show less like this')));
    await gesture.up();
    await _settle(tester);

    expect(find.byType(WallpaperTile).evaluate().length, lessThan(before));
    expect(find.text('Undo'), findsOneWidget);
    verify(() => feedRepository.lessLikeThis(any())).called(1);

    await tester.tap(find.text('Undo'));
    await _settle(tester);

    verify(() => feedRepository.undoLessLikeThis(any())).called(1);
    expect(find.byType(WallpaperTile).evaluate().length, before);
  });

  testWidgets('the tiles the screen builds are reported as shown, once, after a second', (tester) async {
    await pumpScreen(tester);
    verifyNever(() => feedRepository.recordShown(any()));

    await tester.pump(const Duration(seconds: 1));

    final List<Iterable<String>> calls = verify(
      () => feedRepository.recordShown(captureAny()),
    ).captured.cast<Iterable<String>>();
    expect(calls, hasLength(1));
    expect(calls.single, isNotEmpty);
  });

  testWidgets('loading shows skeletons, not a spinner, and the tabs stay usable', (tester) async {
    final Completer<Result<PersonalizedFeedPage>> never = Completer<Result<PersonalizedFeedPage>>();
    when(() => fetchUseCase(any())).thenAnswer((_) => never.future);

    await pumpScreen(tester);

    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.byType(PrismSkeleton), findsOneWidget, reason: 'a card-shaped block holds the carousel place');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a feed with no items explains how to shape it and opens the tune sheet', (tester) async {
    final List<String> haptics = recordHaptics(tester);
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(_page(<String>[])));
    var tuned = 0;

    await pumpScreen(tester, onTuneTap: () => tuned++);

    expect(find.text('Shape this feed'), findsOneWidget);
    await tester.tap(find.text('Tune your feed'));
    await tester.pump();
    expect(tuned, 1);
    expect(haptics, <String>['tap']);
  });

  testWidgets('content shows the grid and the caught up state', (tester) async {
    when(
      () => fetchUseCase(any()),
    ).thenAnswer((_) async => Result.success(_page(<String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'])));

    await pumpScreen(tester);

    expect(find.byType(FeedWallTile), findsWidgets);
    expect(find.byType(PrismWallTile), findsWidgets);
    await tester.scrollUntilVisible(find.text('You are all caught up'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('You are all caught up'), findsOneWidget);
  });

  testWidgets('fetching more shows skeleton tiles, not a spinner', (tester) async {
    int calls = 0;
    final Completer<Result<PersonalizedFeedPage>> nextPage = Completer<Result<PersonalizedFeedPage>>();
    when(() => fetchUseCase(any())).thenAnswer(
      (_) => ++calls == 1
          ? Future<Result<PersonalizedFeedPage>>.value(
              Result.success(_page(<String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'], hasMore: true)),
            )
          : nextPage.future,
    );
    await pumpScreen(tester);

    tester
        .element(find.byType(CustomScrollView))
        .read<PersonalizedFeedBloc>()
        .add(const PersonalizedFeedEvent.fetchMoreRequested());
    await _settle(tester);
    await tester.scrollUntilVisible(find.byType(FeedLoadingMore), 300, scrollable: find.byType(Scrollable).first);

    expect(find.byType(FeedLoadingMore), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('For you load-more retry emits one tap haptic and requests another page', (tester) async {
    final List<String> haptics = recordHaptics(tester);
    int calls = 0;
    final Completer<Result<PersonalizedFeedPage>> retriedPage = Completer<Result<PersonalizedFeedPage>>();
    when(() => fetchUseCase(any())).thenAnswer((_) {
      calls++;
      if (calls == 1) return Future.value(Result.success(_page(<String>['a', 'b', 'c', 'd', 'e', 'f'], hasMore: true)));
      if (calls == 2) return Future.value(Result.error(const NetworkFailure('offline')));
      return retriedPage.future;
    });
    await pumpScreen(tester, disableAnimations: true);
    tester
        .element(find.byType(CustomScrollView))
        .read<PersonalizedFeedBloc>()
        .add(const PersonalizedFeedEvent.fetchMoreRequested());
    await _settle(tester);
    final Finder retry = find.text("Couldn't load more. Try again");
    await tester.ensureVisible(retry);
    haptics.clear();

    await tester.tap(retry);
    await _settle(tester);

    expect(haptics, <String>['tap']);
    expect(calls, 3);
  });

  testWidgets('a paged chip load-more retry emits one tap haptic and requests another page', (tester) async {
    final List<String> haptics = recordHaptics(tester);
    final _MockPagedFeedBloc paged = _MockPagedFeedBloc();
    when(() => paged.state).thenReturn(
      PagedFeedState.initial().copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.failure,
        items: <FeedItemEntity>[_item('a')],
      ),
    );
    final _MockFavouriteBloc favourites = _MockFavouriteBloc();
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: BlocProvider<FavouriteWallsBloc>.value(
            value: favourites,
            child: CustomScrollView(
              slivers: <Widget>[
                PagedChipSliver(
                  bloc: paged,
                  failureTitle: 'Failed',
                  emptyTitle: 'Empty',
                  crossAxisCount: 3,
                  tileMemCacheHeight: 400,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text("Couldn't load more. Try again"));
    await tester.pump();

    expect(haptics, <String>['tap']);
    verify(() => paged.add(const PagedFeedEvent.fetchMoreRequested())).called(1);
  });

  testWidgets('the carousel shows Wall of the Day first, inset by 4 px, with the dots inside the image', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      wotdEntity: const WallOfTheDayEntity(wallId: 'wotd-1', url: '', thumbnailUrl: '', photographer: 'Ana'),
    );

    expect(find.text('Wall of the day'), findsOneWidget);
    expect(find.text('by Ana'), findsOneWidget);
    final Rect card = tester.getRect(find.byType(FeedHeroCard).first);
    final Rect dots = tester.getRect(find.byType(FeedCarouselDots));
    expect(card.left, 4);
    expect(card.width, 592);
    expect(card.height, closeTo(355.2, 0.01));
    expect(dots.top, greaterThanOrEqualTo(card.top));
    expect(dots.bottom, lessThanOrEqualTo(card.bottom));
  });

  testWidgets('the For you grid has a 4 px side margin, 4 px gaps and rounded tiles', (tester) async {
    await pumpScreen(tester);

    final List<Rect> tiles = [for (int i = 0; i < 4; i++) tester.getRect(find.byType(FeedWallTile).at(i))];
    expect(tiles[0].left, 4);
    expect(tiles[2].right, closeTo(596, 0.01));
    expect(tiles[1].left - tiles[0].right, closeTo(4, 0.01));
    expect(tiles[3].top - tiles[0].bottom, closeTo(4, 0.01));
    expect(tester.widget<PrismWallTile>(find.byType(PrismWallTile).first).borderRadius, BorderRadius.circular(12));
  });

  testWidgets('the carousel and the first grid row are 4 px apart', (tester) async {
    await pumpScreen(tester);

    final double carouselBottom = tester.getRect(find.byType(CarouselSlider)).bottom;
    expect(tester.getRect(find.byType(FeedWallTile).first).top - carouselBottom, closeTo(4, 0.01));
  });

  testWidgets('the Latest grid has a 4 px side margin, 4 px gaps and rounded tiles', (tester) async {
    when(
      () => prismRepository.fetchFeed(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('l1'), _wall('l2'), _wall('l3'), _wall('l4')]));
    await pumpScreen(tester);

    await tapTab(tester, 'Latest');
    await _settle(tester);

    final List<Rect> tiles = [for (int i = 0; i < 4; i++) tester.getRect(find.byType(FeedWallTile).at(i))];
    expect(tiles[0].left, 4);
    expect(tiles[1].left - tiles[0].right, closeTo(4, 0.01));
    expect(tiles[3].top - tiles[0].bottom, closeTo(4, 0.01));
    expect(tester.widget<PrismWallTile>(find.byType(PrismWallTile).first).borderRadius, BorderRadius.circular(12));
  });

  group('boosted walls on the home', () {
    DateTime inThreeHours() => DateTime.now().add(const Duration(hours: 3));

    String shownWallId(WidgetTester tester) => tester
        .widget<WallpaperImpression>(
          find.descendant(of: find.byType(CarouselSlider), matching: find.byType(WallpaperImpression)),
        )
        .itemId;

    Future<void> nextPage(WidgetTester tester) async {
      await tester.fling(find.byType(CarouselSlider), const Offset(-300, 0), 1500);
      await _settle(tester);
      await _settle(tester);
    }

    List<String> gridWallIds(WidgetTester tester) =>
        tester.widgetList<FeedWallTile>(find.byType(FeedWallTile)).map((tile) => tile.item.id).toList();

    const WallOfTheDayEntity wotd = WallOfTheDayEntity(
      wallId: 'wotd-1',
      url: '',
      thumbnailUrl: '',
      photographer: 'Ana',
    );

    testWidgets('follow the Wall of the Day in server order, each with a Boosted tag', (tester) async {
      when(() => fetchTrending(any())).thenAnswer(
        (_) async => Result.success(<PrismWallpaper>[
          _wall('hot1', boostedUntil: inThreeHours()),
          _wall('hot2', boostedUntil: inThreeHours()),
          _wall('plain'),
        ]),
      );

      await pumpScreen(tester, disableAnimations: true, wotdEntity: wotd);

      expect(find.text('Wall of the day'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(CarouselSlider), matching: find.byType(WallpaperImpression)),
        findsNothing,
      );
      expect(find.text('Boosted'), findsNothing);

      await nextPage(tester);

      expect(shownWallId(tester), 'hot1');
      expect(find.text('Boosted'), findsOneWidget);
      expect(find.text('Wall of the day'), findsNothing);

      await nextPage(tester);

      expect(shownWallId(tester), 'hot2');
      expect(find.text('Boosted'), findsOneWidget);
    });

    testWidgets('leave out a boost that has ended', (tester) async {
      when(() => fetchTrending(any())).thenAnswer(
        (_) async => Result.success(<PrismWallpaper>[
          _wall('old', boostedUntil: DateTime.now().subtract(const Duration(minutes: 1))),
          _wall('hot1', boostedUntil: inThreeHours()),
        ]),
      );

      await pumpScreen(tester, disableAnimations: true);

      expect(shownWallId(tester), 'hot1');
      expect(tester.widget<FeedCarousel>(find.byType(FeedCarousel)).boostedWalls.map((wall) => wall.id), <String>[
        'hot1',
      ]);
    });

    testWidgets('a boosted wall that is also in the feed shows in the carousel only, not in the grid', (tester) async {
      when(() => fetchTrending(any())).thenAnswer(
        (_) async => Result.success(<PrismWallpaper>[_wall('a', boostedUntil: inThreeHours()), _wall('plain')]),
      );

      await pumpScreen(tester, disableAnimations: true);

      expect(shownWallId(tester), 'a');
      expect(tester.widget<FeedCarousel>(find.byType(FeedCarousel)).previewWalls.map((wall) => wall.id), <String>[
        'b',
        'c',
        'd',
        'e',
      ]);
      expect(gridWallIds(tester), <String>['f', 'g', 'h']);
    });

    testWidgets('with no boosted walls the carousel starts with Wall of the Day and the grid keeps every wall', (
      tester,
    ) async {
      when(() => fetchTrending(any())).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('plain')]));

      await pumpScreen(tester, disableAnimations: true, wotdEntity: wotd);

      expect(find.text('Wall of the day'), findsOneWidget);
      expect(find.text('Boosted'), findsNothing);
      expect(gridWallIds(tester), <String>['e', 'f', 'g', 'h']);
    });

    testWidgets('that arrive after the feed join after the Wall of the Day and do not move the grid', (tester) async {
      final Completer<Result<List<PrismWallpaper>>> late = Completer<Result<List<PrismWallpaper>>>();
      when(() => fetchTrending(any())).thenAnswer((_) => late.future);
      await pumpScreen(tester, disableAnimations: true, wotdEntity: wotd);
      expect(find.text('Wall of the day'), findsOneWidget);
      final Rect carouselBefore = tester.getRect(find.byType(CarouselSlider));
      final double gridTopBefore = tester.getRect(find.byType(FeedWallTile).first).top;

      late.complete(Result.success(<PrismWallpaper>[_wall('hot1', boostedUntil: inThreeHours())]));
      await _settle(tester);

      expect(find.text('Wall of the day'), findsOneWidget);
      expect(find.text('Boosted'), findsNothing);
      expect(tester.getRect(find.byType(CarouselSlider)), carouselBefore);
      expect(tester.getRect(find.byType(FeedWallTile).first).top, gridTopBefore);

      await nextPage(tester);

      expect(shownWallId(tester), 'hot1');
      expect(find.text('Boosted'), findsOneWidget);
    });

    testWidgets('stay out of the other tabs, which have no carousel', (tester) async {
      when(
        () => fetchTrending(any()),
      ).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('hot1', boostedUntil: inThreeHours())]));
      await pumpScreen(tester, disableAnimations: true);

      await tapTab(tester, 'Latest');
      await _settle(tester);

      expect(find.byType(FeedCarousel), findsNothing);
      expect(find.text('Boosted'), findsNothing);
    });
  });

  testWidgets('only a premium wallpaper gets the gold star badge', (tester) async {
    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => Result.success(_page(<String>['a', 'b', 'c', 'd', 'e', 'f', 'g'], premium: <String>{'g'})),
    );

    await pumpScreen(tester);

    expect(find.byType(PremiumStarBadge), findsOneWidget);
  });

  group('carousel', () {
    bool autoPlay(WidgetTester tester) =>
        tester.widget<CarouselSlider>(find.byType(CarouselSlider, skipOffstage: false)).options.autoPlay;

    testWidgets('turns pages by itself while the feed is on screen', (tester) async {
      await pumpScreen(tester);

      expect(autoPlay(tester), isTrue);
    });

    testWidgets('stays still under reduce motion', (tester) async {
      await pumpScreen(tester, disableAnimations: true);

      expect(autoPlay(tester), isFalse);
    });

    testWidgets('stays still while another tab hides the feed', (tester) async {
      await pumpScreen(tester, tickersEnabled: false);

      expect(autoPlay(tester), isFalse);
    });

    testWidgets('stops while a screen is pushed over the feed and resumes when it closes', (tester) async {
      await pumpScreen(tester);
      final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator));

      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('covering')))));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('covering'), findsOneWidget);
      expect(autoPlay(tester), isFalse);

      navigator.pop();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(autoPlay(tester), isTrue);
    });

    testWidgets('decodes its wallpaper tiles at the carousel height', (tester) async {
      await pumpScreen(tester);

      final Iterable<PrismImageTile> tiles = tester.widgetList<PrismImageTile>(
        find.descendant(of: find.byType(CarouselSlider), matching: find.byType(PrismImageTile)),
      );

      // 600 px wide at a pixel ratio of 1, so the page is 592 px wide and 0.6 as tall: 355.2 px.
      expect(tiles, isNotEmpty);
      expect(tiles.map((tile) => tile.memCacheHeight), everyElement(355));
    });
  });

  testWidgets('the feed keeps 1.5 screens of tiles ready beyond the viewport', (tester) async {
    await pumpScreen(tester);

    final CustomScrollView scrollView = tester.widget<CustomScrollView>(find.byType(CustomScrollView));

    expect(scrollView.scrollCacheExtent, isA<ScrollCacheExtent>());
    expect(scrollView.scrollCacheExtent!.value, 1.5);
  });

  testWidgets('the first load shows skeletons laid out like the grid', (tester) async {
    final Completer<Result<PersonalizedFeedPage>> never = Completer<Result<PersonalizedFeedPage>>();
    when(() => fetchUseCase(any())).thenAnswer((_) => never.future);

    await pumpScreen(tester);

    expect(tester.widget<LoadingCards>(find.byType(LoadingCards)).useFeedLayout, isTrue);
    expect(tab('Latest'), findsOneWidget, reason: 'the tabs are usable while it loads');
    final Finder bone = find.descendant(of: find.byType(PrismSkeleton), matching: find.byType(PrismBone));
    expect(tester.getRect(bone).left, 4);
    expect(tester.getSize(bone).width, 592);
    expect(tester.getSize(bone).height, closeTo(355.2, 0.01));
  });

  testWidgets('a failed first load offers Try again and loads again', (tester) async {
    int calls = 0;
    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => ++calls == 1
          ? Result.error(const NetworkFailure('offline'))
          : Result.success(_page(<String>['a', 'b', 'c', 'd', 'e', 'f'])),
    );
    await pumpScreen(tester);
    expect(find.text("Couldn't load your feed"), findsOneWidget);

    await tester.tap(find.widgetWithText(PrismButton, 'Try again'));
    await _settle(tester);

    expect(find.text("Couldn't load your feed"), findsNothing);
    expect(find.byType(WallpaperTile), findsWidgets);
  });

  testWidgets('a changed content filter loads the feed again', (tester) async {
    await pumpScreen(tester);
    verify(() => fetchUseCase(any())).called(1);
    clearInteractions(fetchUseCase);

    personalizedFeedSettingsRevision.value += 1;
    await _settle(tester);

    verify(() => fetchUseCase(any())).called(1);
  });

  group('floating header', () {
    bool shown(WidgetTester tester, Finder finder) => finder.evaluate().isNotEmpty && tester.getRect(finder).bottom > 0;

    Future<void> scroll(WidgetTester tester, double dy) async {
      await tester.drag(find.byType(CustomScrollView), Offset(0, dy));
      await _settle(tester);
      await _settle(tester);
    }

    testWidgets('sits at the top at first: the top bar is 52 high and the tabs are 44 high under it', (tester) async {
      await pumpScreen(tester, viewSize: const Size(600, 800));

      expect(tester.getRect(find.byType(PrismTopAppBar)), const Rect.fromLTWH(0, 0, 600, 52));
      expect(tester.getRect(find.byType(HomeFeedTabBar)), const Rect.fromLTWH(0, 52, 600, 44));
    });

    testWidgets('scrolling down hides the top bar and the tabs, and a small scroll up brings them back', (
      tester,
    ) async {
      await pumpScreen(tester, viewSize: const Size(600, 800));

      await scroll(tester, -700);

      expect(shown(tester, find.byType(PrismAvatar)), isFalse);
      expect(shown(tester, find.byType(HomeFeedTabBar)), isFalse);

      await scroll(tester, 80);

      expect(shown(tester, find.byType(PrismAvatar)), isTrue);
      expect(tester.getRect(find.byType(PrismTopAppBar)).top, 0);
      expect(tester.getRect(find.byType(HomeFeedTabBar)).bottom, 96);
    });

    testWidgets('keeps a solid status bar strip, and the header slides in under it, not behind it', (tester) async {
      await pumpScreen(tester, viewSize: const Size(600, 800), statusBar: 47);

      expect(tester.getRect(find.byType(PrismTopAppBar)).top, 47);
      expect(tester.getRect(find.byType(HomeFeedTabBar)).bottom, 47 + 96);

      await scroll(tester, -700);
      expect(shown(tester, find.byType(PrismAvatar)), isFalse);
      final Finder strip = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == Theme.of(tester.element(find.byType(CustomScrollView))).colorScheme.surface &&
            tester.getRect(find.byWidget(widget)) == const Rect.fromLTWH(0, 0, 600, 47),
      );
      expect(strip, findsOneWidget);

      await scroll(tester, 80);

      expect(tester.getRect(find.byType(PrismTopAppBar)).top, 47);
      expect(tester.getRect(find.byType(HomeFeedTabBar)).bottom, 47 + 96);
    });

    testWidgets('the pull to refresh spinner shows under the header', (tester) async {
      await pumpScreen(tester, viewSize: const Size(600, 800), statusBar: 47);

      expect(tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).edgeOffset, 96);
    });

    testWidgets('choosing a tab starts it at the top', (tester) async {
      await pumpScreen(tester, viewSize: const Size(600, 800));
      await scroll(tester, -700);
      await scroll(tester, 80);
      final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scrollable.position.pixels, greaterThan(0));

      await tapTab(tester, 'Popular');
      await _settle(tester);

      expect(scrollable.position.pixels, 0);
      expect(tester.getRect(find.byType(PrismTopAppBar)).top, 0);
    });
  });
}

PrismUsersV2 _user({required bool loggedIn}) {
  final String now = DateTime.now().toUtc().toIso8601String();
  return PrismUsersV2(
    username: '',
    email: 'me@example.com',
    id: 'me',
    createdAt: now,
    premium: false,
    lastLoginAt: now,
    links: const <String, String>{},
    followers: const <String>[],
    following: const <String>[],
    profilePhoto: '',
    bio: '',
    loggedIn: loggedIn,
    badges: const [],
    subPrisms: const <String>[],
    coins: 0,
    transactions: const [],
    name: '',
    coverPhoto: '',
  );
}

/// The skeletons and the progress bar animate for ever, so `pumpAndSettle` would hang.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
