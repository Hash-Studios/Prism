import 'dart:async';
import 'dart:io' show SocketException;

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/paged_chip_sliver.dart';
import 'package:Prism/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/in_memory_local_store.dart';

class _MockFetchUseCase extends Mock implements FetchPersonalizedFeedUseCase {}

class _MockFeedRepository extends Mock implements PersonalizedFeedRepository {}

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockFetchTrending extends Mock implements FetchTrendingUseCase {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

class _MockFavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _MockPagedFeedBloc extends MockBloc<PagedFeedEvent, PagedFeedState> implements PagedFeedBloc {}

FeedItemEntity _item(String id, {List<String>? collections}) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', authorEmail: '$id@x.com'),
    collections: collections,
  ),
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

void main() {
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
    registerFallbackValue(TrendingRange.week);
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
    ).thenAnswer((_) async => Result.success(<PrismWallpaper>[(_item('late1') as PrismFeedItem).wallpaper]));
    when(() => prismRepository.hasMore).thenReturn(false);
    when(
      () => fetchUseCase(any()),
    ).thenAnswer((_) async => Result.success(_page(<String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'], hasMore: true)));
    fetchTrending = _MockFetchTrending();
    when(() => fetchTrending(any())).thenAnswer((_) async => Result.success(<PrismWallpaper>[]));
    app_state.prismUser = _user(loggedIn: true);
    getIt
      ..registerFactory<PersonalizedFeedBloc>(
        () => PersonalizedFeedBloc(fetchUseCase, feedRepository, FakeUserBlockRepository.pending()),
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
  }) async {
    // Tall, so the carousel, the chips and the first rows of tiles are all on screen.
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wotd = _MockWotdBloc();
    when(() => wotd.state).thenReturn(
      WotdState.initial().copyWith(
        status: wotdEntity == null ? LoadStatus.initial : LoadStatus.success,
        entity: wotdEntity,
      ),
    );
    final favourites = _MockFavouriteBloc();
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: Scaffold(
          body: TickerMode(
            enabled: tickersEnabled,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<WotdBloc>.value(value: wotd),
                BlocProvider<FavouriteWallsBloc>.value(value: favourites),
              ],
              child: PersonalizedFeedScreen(onTuneTap: onTuneTap),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('shows the four chips under the title, with For you chosen', (tester) async {
    await pumpScreen(tester);

    for (final label in <String>['For you', 'Latest', 'Following', 'Popular']) {
      expect(find.widgetWithText(PrismChip, label), findsOneWidget);
    }
    expect(tester.widget<PrismChip>(find.widgetWithText(PrismChip, 'For you')).selected, isTrue);
    expect(find.byType(WallpaperTile), findsWidgets);
  });

  testWidgets('hides the Trending strip when nothing is trending', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Trending this week'), findsNothing);
    expect(find.text('For you'), findsWidgets);
  });

  testWidgets('shows the Trending strip above the For you title', (tester) async {
    when(
      () => fetchTrending(TrendingRange.week),
    ).thenAnswer((_) async => Result.success(<PrismWallpaper>[(_item('hot1') as PrismFeedItem).wallpaper]));

    await pumpScreen(tester);

    expect(find.text('Trending this week'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Trending this week')).dy,
      lessThan(tester.getTopLeft(find.text('For you').first).dy),
    );
  });

  testWidgets('pull to refresh reloads the Trending strip too', (tester) async {
    await pumpScreen(tester);
    verify(() => fetchTrending(TrendingRange.week)).called(1);

    await tester.drag(
      find.descendant(of: find.byType(RefreshIndicator), matching: find.byType(CustomScrollView)).first,
      const Offset(0, 1200),
    );
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(() => fetchTrending(TrendingRange.week)).called(1);
  });

  for (final String chip in <String>['Latest', 'Popular', 'Following']) {
    testWidgets('pull to refresh on the $chip chip reloads the Trending strip too', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.widgetWithText(PrismChip, chip));
      await _settle(tester);
      verify(() => fetchTrending(TrendingRange.week)).called(1);

      await tester.drag(
        find.descendant(of: find.byType(RefreshIndicator), matching: find.byType(CustomScrollView)).first,
        const Offset(0, 1200),
      );
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      verify(() => fetchTrending(TrendingRange.week)).called(1);
    });
  }

  testWidgets('the Latest chip loads the newest Prism walls', (tester) async {
    await pumpScreen(tester);
    verifyNever(() => prismRepository.fetchFeed(refresh: any(named: 'refresh')));

    await tester.tap(find.widgetWithText(PrismChip, 'Latest'));
    await _settle(tester);

    verify(() => prismRepository.fetchFeed(refresh: true)).called(1);
    expect(tester.widget<PrismChip>(find.widgetWithText(PrismChip, 'Latest')).selected, isTrue);
    expect(find.byType(WallpaperTile), findsOneWidget);
  });

  testWidgets('the Popular chip shows the popular walls', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(PrismChip, 'Popular'));
    await _settle(tester);

    verify(() => feedRepository.fetchPopular()).called(1);
    expect(find.byType(WallpaperTile), findsNWidgets(2));
  });

  testWidgets('a chip is loaded once, however often the user comes back to it', (tester) async {
    await pumpScreen(tester);

    for (final label in <String>['Popular', 'For you', 'Popular']) {
      await tester.tap(find.widgetWithText(PrismChip, label));
      await _settle(tester);
    }

    verify(() => feedRepository.fetchPopular()).called(1);
  });

  testWidgets('Following with nobody followed explains how to fill it and offers a way to find creators', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(PrismChip, 'Following'));
    await _settle(tester);

    expect(find.text('Follow creators to see their new wallpapers here'), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Find creators'), findsOneWidget);
    expect(find.byType(WallpaperTile), findsNothing);
  });

  testWidgets('Following lists the followed creators walls', (tester) async {
    when(
      () => feedRepository.fetchFollowing(page: 1),
    ).thenAnswer((_) async => Result.success(_page(<String>['f1', 'f2', 'f3'])));
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(PrismChip, 'Following'));
    await _settle(tester);

    expect(find.byType(WallpaperTile), findsNWidgets(3));
  });

  testWidgets('a guest is asked to sign in on the Following chip and nothing is fetched', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(PrismChip, 'Following'));
    await _settle(tester);

    expect(find.text('Sign in to use following'), findsOneWidget);
    verifyNever(() => feedRepository.fetchFollowing(page: any(named: 'page')));
  });

  testWidgets('a failed Latest load offers Try again', (tester) async {
    when(
      () => prismRepository.fetchFeed(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => Result.error(const NetworkFailure('x')));
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(PrismChip, 'Latest'));
    await _settle(tester);

    expect(find.text("Couldn't load the latest wallpapers"), findsOneWidget);
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
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(updating, findsOneWidget);

    fresh.complete(Result.success(_page(<String>['n1', 'n2', 'n3', 'n4', 'n5', 'n6', 'n7'])));
    await _settle(tester);

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Show less like this gives an Undo that brings the wallpaper back', (tester) async {
    await pumpScreen(tester);
    final int before = find.byType(WallpaperTile).evaluate().length;
    await tester.longPress(find.byType(WallpaperTile).first);
    await _settle(tester);

    await tester.tap(find.text('Show less like this'));
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

  testWidgets('loading shows skeletons, not a spinner, and the chips stay usable', (tester) async {
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

  testWidgets('content shows the For you header, a tune button, the grid and the caught up state', (tester) async {
    when(
      () => fetchUseCase(any()),
    ).thenAnswer((_) async => Result.success(_page(<String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'])));
    var tuned = 0;

    await pumpScreen(tester, onTuneTap: () => tuned++);

    expect(find.text('For you'), findsNWidgets(2), reason: 'the header and the chip');
    await tester.tap(find.byTooltip('Tune your feed'));
    expect(tuned, 1);
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

  testWidgets('the carousel shows Wall of the Day first, with dots under the card', (tester) async {
    await pumpScreen(
      tester,
      wotdEntity: const WallOfTheDayEntity(wallId: 'wotd-1', url: '', thumbnailUrl: '', photographer: 'Ana'),
    );

    expect(find.text('Wall of the day'), findsOneWidget);
    expect(find.text('by Ana'), findsOneWidget);
    final Size card = tester.getSize(find.byType(FeedHeroCard).first);
    expect(card.width, 600 - 2 * PrismWallGrid.margin);
    expect(card.height / card.width, closeTo(0.56, 0.01));
    expect(
      tester.getTopLeft(find.byType(FeedCarouselDots)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(FeedHeroCard).first).dy),
    );
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

      // 600 px wide at a pixel ratio of 1, so the card is 576 px wide and 0.56 as tall: 322.56 px.
      expect(tiles, isNotEmpty);
      expect(tiles.map((tile) => tile.memCacheHeight), everyElement(323));
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
    expect(find.widgetWithText(PrismChip, 'Latest'), findsOneWidget, reason: 'the chips are usable while it loads');
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
