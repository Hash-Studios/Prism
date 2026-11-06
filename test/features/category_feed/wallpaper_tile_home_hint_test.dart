import 'dart:async';
import 'dart:io' show SocketException;

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/gesture_hint.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/domain/repositories/drops_repository.dart';
import 'package:Prism/features/editors_choice/biz/editors_choice_cubit.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/moods/biz/mood_walls_cubit.dart';
import 'package:Prism/features/moods/biz/moods_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/weekly_challenges/biz/weekly_challenges_cubit.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/empty_editors_choice_repository.dart';
import '../../support/empty_weekly_challenges_repository.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';
import '../creator_directory/creator_directory_test_support.dart';

class _MockFetchUseCase extends Mock implements FetchPersonalizedFeedUseCase {}

class _MockFeedRepository extends Mock implements PersonalizedFeedRepository {}

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockFetchTrending extends Mock implements FetchTrendingUseCase {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

class _MockFavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _MockNotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

class _NoMoods implements MoodRepository {
  @override
  Stream<void> watchVisibilityChanges() => const Stream<void>.empty();

  @override
  Future<List<MoodList>> fetchMoods() async => const <MoodList>[];

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids, {bool keepOrder = false}) async =>
      const <PrismWallpaper>[];
}

class _NoDrops implements DropsRepository {
  @override
  Future<Result<DropEntity?>> fetchLive(DateTime now) async => Result.success<DropEntity?>(null);

  @override
  Future<Result<DropEntity?>> fetchByWeekKey(String weekKey) async => Result.success<DropEntity?>(null);

  @override
  Future<Result<String>> rename(String weekKey, String title) async => Result.success(title);
}

FeedItemEntity _item(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', authorEmail: '$id@x.com'),
  ),
);

PrismUsersV2 _signedIn() {
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
    loggedIn: true,
    badges: const [],
    subPrisms: const <String>[],
    coins: 0,
    transactions: const [],
    name: '',
    coverPhoto: '',
  );
}

void main() {
  setUpFavouriteCounts();

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
    GestureHints.resetForTest();
    final cache = _MockCacheManager();
    PrismImageCache.testOverride = cache;
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) => Stream<FileResponse>.error(const SocketException('offline')));
    final fetch = _MockFetchUseCase();
    final feedRepository = _MockFeedRepository();
    final prismRepository = _MockPrismRepository();
    final fetchTrending = _MockFetchTrending();
    final blocks = FakeUserBlockRepository.pending();
    final List<String> ids = List<String>.generate(12, (i) => 'wall-$i');
    final page = PersonalizedFeedPage(items: ids.map(_item).toList(), hasMore: false, usedKeys: ids);
    when(() => fetch(any())).thenAnswer((_) async => Result.success(page));
    when(() => feedRepository.readCached()).thenAnswer((_) async => null);
    when(() => feedRepository.recordShown(any())).thenAnswer((_) async {});
    when(() => prismRepository.fetchFeed(refresh: any(named: 'refresh'))).thenAnswer((_) async => Result.success([]));
    when(() => prismRepository.hasMore).thenReturn(false);
    when(() => fetchTrending(any())).thenAnswer((_) async => TrendingFetch.success(<PrismWallpaper>[]));
    app_state.prismUser = _signedIn();
    final MoodRepository moods = _NoMoods();
    getIt
      ..registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()))
      ..registerFactory<WeeklyChallengesCubit>(() => WeeklyChallengesCubit(const EmptyWeeklyChallengesRepository()))
      ..registerFactory<PersonalizedFeedBloc>(() => PersonalizedFeedBloc(fetch, feedRepository, blocks, _NoDrops()))
      ..registerFactory<LatestFeedBloc>(() => LatestFeedBloc(prismRepository))
      ..registerFactory<FollowingFeedBloc>(() => FollowingFeedBloc(feedRepository))
      ..registerFactory<PopularFeedBloc>(() => PopularFeedBloc(feedRepository))
      ..registerFactory<TrendingBloc>(() => TrendingBloc(fetchTrending, FakeUserBlockRepository.pending()))
      ..registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()))
      ..registerSingleton<UserBlockRepository>(blocks)
      ..registerLazySingleton<MoodsCubit>(() => MoodsCubit(moods))
      ..registerFactory<MoodWallsCubit>(() => MoodWallsCubit(moods))
      ..registerFactory<EditorsChoiceCubit>(() => EditorsChoiceCubit(const EmptyEditorsChoiceRepository()));
    registerCreatorDirectoryFakes();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    PrismImageCache.testOverride = null;
    GestureHints.resetForTest();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  testWidgets('the first Home grid tile teaches hold once, and the hint leaves when the hold is used', (tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wotd = _MockWotdBloc();
    when(() => wotd.state).thenReturn(WotdState.initial());
    final favourites = _MockFavouriteBloc();
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
    final notifications = _MockNotificationsBloc();
    when(() => notifications.state).thenReturn(InAppNotificationsState.initial());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: favouriteTestBuilder,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<WotdBloc>.value(value: wotd),
              BlocProvider<FavouriteWallsBloc>.value(value: favourites),
              BlocProvider<InAppNotificationsBloc>.value(value: notifications),
            ],
            child: const PersonalizedFeedScreen(),
          ),
        ),
      ),
    );
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(WallpaperTile), findsAtLeastNWidgets(4));
    final Finder hint = find.byType(GestureHintOverlay);
    expect(hint, findsOneWidget);
    expect(find.descendant(of: find.byType(WallpaperTile).first, matching: hint), findsOneWidget);
    expect(find.text('Hold to save'), findsOneWidget);
    double opacity() =>
        tester.widget<AnimatedOpacity>(find.descendant(of: hint, matching: find.byType(AnimatedOpacity))).opacity;
    expect(opacity(), 1);

    GestureHints.markSeen(GestureHint.holdToSave);
    await tester.pump();
    expect(opacity(), 0);
    expect(getIt<SettingsLocalDataSource>().get<bool>('gestureHintSeen.holdToSave', defaultValue: false), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
