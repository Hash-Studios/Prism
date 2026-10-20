@Tags(<String>['qa_render'])
library;

import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/domain/repositories/drops_repository.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_user_block_repository.dart';
import '../support/in_memory_local_store.dart';
import 'home_render_support.dart';

class _MockFetchUseCase extends Mock implements FetchPersonalizedFeedUseCase {}

class _MockFeedRepository extends Mock implements PersonalizedFeedRepository {}

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockFetchTrending extends Mock implements FetchTrendingUseCase {}

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

class _MockFavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _MockNotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

class _FakeTabsRouter extends ChangeNotifier implements TabsRouter {
  @override
  int get activeIndex => 0;

  @override
  StackRouter? stackRouterOfIndex(int index) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const int _pageSize = 30;

/// Wall number [n] with creator, size and photo fixed by [n], so the same number always shows the same picture.
PrismWallpaper _wall(int n, {bool boosted = false, bool premium = false}) {
  final String photo = photoUrl(portraitPhotos[n % portraitPhotos.length]);
  return PrismWallpaper(
    core: WallpaperCore(
      id: 'qa$n',
      source: WallpaperSource.prism,
      fullUrl: photo,
      thumbnailUrl: photo,
      authorName: 'Creator $n',
      authorEmail: 'creator$n@example.com',
      category: 'Nature',
      width: 1080,
      height: 2160,
      favourites: 20 + n * 3,
    ),
    title: 'Wall $n',
    collections: premium ? const <String>['space'] : null,
    boostedUntil: boosted ? DateTime.now().add(const Duration(hours: 3)) : null,
  );
}

FeedItemEntity _item(int n, {bool premium = false}) => FeedItemEntity.prism(
  id: 'qa$n',
  wallpaper: _wall(n, premium: premium),
);

PersonalizedFeedPage _page(Iterable<int> numbers, {bool hasMore = true}) {
  final List<FeedItemEntity> items = <FeedItemEntity>[for (final int n in numbers) _item(n, premium: n % 7 == 3)];
  return PersonalizedFeedPage(
    items: items,
    hasMore: hasMore,
    usedKeys: <String>[for (final FeedItemEntity i in items) i.id],
  );
}

PrismUsersV2 _signedInUser() {
  final String now = DateTime.now().toUtc().toIso8601String();
  return PrismUsersV2(
    username: 'alex',
    email: 'me@example.com',
    id: 'me',
    createdAt: now,
    premium: false,
    lastLoginAt: now,
    links: const <String, String>{},
    followers: const <String>[],
    following: const <String>[],
    profilePhoto: photoUrl('avatar.jpg'),
    bio: '',
    loggedIn: true,
    badges: const [],
    subPrisms: const <String>[],
    coins: 0,
    transactions: const [],
    name: 'Alex Rivera',
    coverPhoto: '',
  );
}

final List<PersonalizedInterest> _catalog = <PersonalizedInterest>[
  for (final (int i, String name) in <String>[
    'Nature',
    'Abstract',
    'Space',
    'Minimal',
    'Cars',
    'Cities',
    'Dark',
    'Animals',
  ].indexed)
    PersonalizedInterest(
      name: name,
      query: name,
      imageUrl: photoUrl(portraitPhotos[i * 3]),
      sources: const <WallpaperSource>[],
    ),
];

/// One mounted home: the real floating bar host around the real feed screen, fed by seeded fakes.
class _Home {
  _Home(this.tester, this.theme) : shot = HomeShot(tester);

  final WidgetTester tester;
  final ThemeData theme;
  final HomeShot shot;

  final _MockFetchUseCase fetchUseCase = _MockFetchUseCase();
  final _MockFeedRepository feedRepository = _MockFeedRepository();
  final _MockPrismRepository prismRepository = _MockPrismRepository();
  final _MockFetchTrending fetchTrending = _MockFetchTrending();
  final MockStackRouter stackRouter = MockStackRouter();
  final _FakeTabsRouter tabsRouter = _FakeTabsRouter();

  void _stubData() {
    when(() => feedRepository.readCached()).thenAnswer((_) async => null);
    when(() => feedRepository.recordShown(any())).thenAnswer((_) async {});
    when(() => feedRepository.lessLikeThis(any())).thenAnswer((_) async {});
    when(() => feedRepository.undoLessLikeThis(any())).thenAnswer((_) async {});
    when(
      () => feedRepository.fetchFollowing(page: any(named: 'page')),
    ).thenAnswer((_) async => Result.success(_page(<int>[for (int i = 0; i < 24; i++) 100 + i * 5], hasMore: false)));
    when(
      () => feedRepository.fetchPopular(),
    ).thenAnswer((_) async => Result.success(_page(<int>[for (int i = 0; i < 24; i++) 200 + i * 7], hasMore: false)));
    when(
      () => prismRepository.fetchFeed(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => Result.success(<PrismWallpaper>[for (int i = 0; i < 24; i++) _wall(300 + i * 11)]));
    when(() => prismRepository.hasMore).thenReturn(false);
    when(() => fetchUseCase(any())).thenAnswer((Invocation invocation) async {
      final FetchPersonalizedFeedRequest request = invocation.positionalArguments.first as FetchPersonalizedFeedRequest;
      final int start = (request.page - 1) * _pageSize;
      return Result.success(_page(<int>[for (int i = start; i < start + _pageSize; i++) i]));
    });
    when(() => fetchTrending(any())).thenAnswer(
      (_) async => Result.success(<PrismWallpaper>[for (int i = 0; i < 18; i++) _wall(400 + i * 5, boosted: i < 2)]),
    );
    when(() => stackRouter.push(any())).thenAnswer((_) async => null);
    when(() => stackRouter.pushPath(any())).thenAnswer((_) async => null);
  }

  Future<void> pump() async {
    shot.configureView();
    QaPhotoCache.install();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = _signedInUser();
    _stubData();
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

    final _MockWotdBloc wotd = _MockWotdBloc();
    whenListen(
      wotd,
      const Stream<WotdState>.empty(),
      initialState: WotdState.initial().copyWith(
        status: LoadStatus.success,
        entity: WallOfTheDayEntity(
          wallId: 'qa-wotd',
          url: photoUrl('l01.jpg'),
          thumbnailUrl: photoUrl('l01.jpg'),
          photographer: 'Maya Chen',
        ),
      ),
    );
    final _MockFavouriteBloc favourites = _MockFavouriteBloc();
    whenListen(favourites, const Stream<FavouriteWallsState>.empty(), initialState: FavouriteWallsState.initial());
    final _MockNotificationsBloc notifications = _MockNotificationsBloc();
    whenListen(
      notifications,
      const Stream<InAppNotificationsState>.empty(),
      initialState: InAppNotificationsState.initial().copyWith(status: LoadStatus.success, unreadCount: 3),
    );

    await tester.pumpWidget(
      shot.frame(
        brightness: theme.brightness,
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          debugShowCheckedModeBanner: false,
          theme: theme,
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<WotdBloc>.value(value: wotd),
              BlocProvider<FavouriteWallsBloc>.value(value: favourites),
              BlocProvider<InAppNotificationsBloc>.value(value: notifications),
            ],
            child: TabsRouterScope(
              controller: tabsRouter,
              stateHash: 0,
              child: StackRouterScope(
                controller: stackRouter,
                stateHash: 0,
                child: Builder(
                  builder: (BuildContext context) => Scaffold(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    body: BottomBar(child: PersonalizedFeedScreen(onTuneTap: openFeedSettings)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await shot.settle(frames: 10);
    // The avatar goes through the package cache manager, whose chain of file reads needs one real pump per step.
    await shot.settle(frames: 14, frameMs: 50);
  }

  /// The feed settings sheet with the same content the real opener builds, minus Firebase Remote Config.
  void openFeedSettings() {
    final BuildContext context = tester.element(find.byType(PersonalizedFeedScreen));
    final TasteSignalStore store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
    unawaited(
      showPrismSheet<void>(
        context,
        detents: const <PrismSheetDetent>[PrismSheetDetent.large],
        builder: (BuildContext sheetContext) => PersonalizedFeedSettingsSheet(
          catalog: _catalog,
          initialInterests: const <String>{'Nature', 'Abstract', 'Space', 'Cities'},
          initialFeedMix: FeedMix.balanced,
          tasteSignals: store,
          onSave: (List<String> interests, FeedMix mix) async => true,
        ),
      ),
    );
  }

  Future<void> tapTab(String label) async {
    await tester.tap(find.text(label).first);
    await shot.settle(frames: 10);
    await shot.settle(frames: 14, frameMs: 50);
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox.shrink());
    // The default cache manager schedules a 10 s cleanup after each lookup, and a test may not end with a pending timer.
    await tester.pump(const Duration(seconds: 11));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    QaPhotoCache.uninstall();
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  }
}

class _FakeDropsRepository implements DropsRepository {
  @override
  Future<Result<DropEntity?>> fetchLive(DateTime now) async => Result.success<DropEntity?>(null);

  @override
  Future<Result<DropEntity?>> fetchByWeekKey(String weekKey) async => Result.success<DropEntity?>(null);
}

void main() {
  final List<String> results = <String>[];

  setUpAll(() async {
    registerFallbackValue(
      const FetchPersonalizedFeedRequest(
        page: 1,
        refresh: true,
        seenKeys: <String>[],
        existingItems: <FeedItemEntity>[],
      ),
    );
    registerFallbackValue(_item(0));
    registerFallbackValue(const NoParams());
    registerFallbackValue(ProfileRoute());
    if (homeRender) await loadAppFonts();
  });

  tearDownAll(() {
    if (!homeRender) return;
    final File summary = File('$renderDir/_results.txt');
    summary.parent.createSync(recursive: true);
    summary.writeAsStringSync('${results.join('\n')}\n');
    // ignore: avoid_print
    print('\nQA_RENDER results\n${results.join('\n')}');
  });

  /// Registers one scene. A failure is logged and the run goes on, and the PNG is still saved when the scene got far
  /// enough to draw, so a layout overflow does not hide the picture.
  void scene(String name, ThemeData theme, Future<void> Function(_Home home) body) {
    testWidgets(name, skip: !homeRender, (WidgetTester tester) async {
      final _Home home = _Home(tester, theme);
      bool saved = false;
      try {
        await home.pump();
        await body(home);
        await home.shot.save(name);
        saved = true;
        final Object? exception = tester.takeException();
        results.add(exception == null ? 'OK    $name' : 'WARN  $name rendered with a framework exception: $exception');
      } catch (error, stack) {
        results.add('FAIL  $name: $error');
        // ignore: avoid_print
        print('QA_RENDER scene $name failed\n$error\n$stack');
        if (!saved) {
          try {
            await home.shot.save('$name--partial');
            results.add('      partial picture saved as $name--partial.png');
          } catch (_) {}
        }
        tester.takeException();
      } finally {
        try {
          await home.dispose();
        } catch (error) {
          results.add('      teardown after $name failed: $error');
        }
      }
    });
  }

  scene('01-home-top-dark', kDarkTheme, (_) async {});

  scene('02-home-scrolled-dark', kDarkTheme, (_Home home) => home.shot.scrollBy(-900));

  scene('03-home-scroll-up-dark', kDarkTheme, (_Home home) async {
    await home.shot.scrollBy(-900);
    await home.shot.scrollBy(120);
  });

  scene('04-trending-dark', kDarkTheme, (_Home home) => home.tapTab('Trending'));

  scene('05-following-dark', kDarkTheme, (_Home home) => home.tapTab('Following'));

  scene('06-home-top-light', kLightTheme, (_) async {});

  scene('07-feed-settings-dark', kDarkTheme, (_Home home) async {
    await home.tapTab('For you');
    // Eight interest tiles each go through the package cache manager, one real pump per step.
    await home.shot.settle(frames: 30, frameMs: 40);
  });
}
