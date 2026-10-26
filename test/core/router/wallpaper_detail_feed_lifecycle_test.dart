import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wallpaper_recommendation_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/offline_asset_fixture.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

class _PrismRepository extends Mock implements PrismWallpaperRepository {}

class _WallhavenRepository extends Mock implements WallhavenWallpaperRepository {}

class _PexelsRepository extends Mock implements PexelsWallpaperRepository {}

class _PaletteRepository extends Mock implements PaletteRepository {}

class _StatsRepository extends Mock implements ViewStatsRepository {}

class _Recommendations implements WallpaperRecommendationRepository {
  final visits = <({String wallId, String session})>[];
  final released = <String>[];

  @override
  Future<RecommendationPage> load({
    required FeedItemEntity current,
    required String sessionKey,
    RecommendationCursor? cursor,
  }) async {
    visits.add((wallId: current.id, session: sessionKey));
    return RecommendationPage(items: [], kind: RecommendationKind.related);
  }

  @override
  void release(String sessionKey) => released.add(sessionKey);
}

FeedItemEntity _item(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      authorName: id,
      width: 1080,
      height: 1920,
    ),
  ),
);

class _FeedRouter extends RootStackRouter {
  _FeedRouter(this.feed);

  final List<FeedItemEntity> feed;
  ModalRoute<dynamic>? detail;

  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Grid',
        builder: (_) => const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              height: 140,
              child: Hero(
                tag: 'tile',
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    ),
    CustomRoute(
      path: '/detail',
      page: PageInfo(
        'Detail',
        builder: (_) => Builder(
          builder: (context) {
            detail = ModalRoute.of(context);
            return WallpaperDetailScreen(entity: feed[1], feed: feed, heroTag: 'tile').wrappedRoute(context);
          },
        ),
      ),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
  ];
}

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture assets;
  final created = <_MockDetailBloc>[];
  final closed = <_MockDetailBloc>[];
  final queued = <FeedItemEntity>[];

  setUp(() async {
    created.clear();
    closed.clear();
    queued.clear();
    assets = await OfflineAssetFixture.create();
    assets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = _MockDetailBloc();
      whenListen(
        bloc,
        const Stream<WallpaperDetailState>.empty(),
        initialState: WallpaperDetailLoaded(
          entity: queued.removeAt(0),
          paletteLoading: false,
          recommendations: const RecommendationState.exhausted(),
        ),
      );
      when(() => bloc.close()).thenAnswer((_) async => closed.add(bloc));
      created.add(bloc);
      return bloc;
    });
  });

  tearDown(() async {
    await assets.dispose();
    await getIt.reset();
  });

  test('feed route arguments compare list values and preserve the optional no-feed path', () {
    final feed = [_item('a'), _item('b')];
    final first = WallpaperDetailRoute(entity: feed[1], feed: feed).args!;
    final equivalent = WallpaperDetailRoute(entity: feed[1], feed: List.of(feed)).args!;
    expect(first, equivalent);
    expect(first.hashCode, equivalent.hashCode);
    expect(first, isNot(WallpaperDetailRoute(entity: feed[1], feed: feed.reversed.toList()).args));
    expect(first.feed, same(feed));
    final standalone = WallpaperDetailRoute(wallId: 'linked-wall', source: WallpaperSource.wallhaven).args!;
    expect(standalone.feed, isNull);
    expect(standalone.wallId, 'linked-wall');
    expect(standalone.source, WallpaperSource.wallhaven);
  });

  Future<_FeedRouter> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final feed = [_item('a'), _item('b'), _item('c')];
    final router = _FeedRouter(feed);
    queued.add(feed[1]);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('iOS edge back beats the card drag recognizer and does not open a previous wall', (tester) async {
    final router = await open(tester);
    final card = tester.getRect(find.byType(WallpaperQuickActionRegion).first);
    expect(card.left, lessThan(10));
    expect(router.detail!.popGestureEnabled, isTrue);
    final gesture = await tester.startGesture(Offset(10, card.center.dy));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
    await gesture.moveBy(const Offset(260, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(router.current.name, 'Grid');
    expect(created, hasLength(1));
    expect(closed, created);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS centre drag changes wall, keeps native back, and closes the old bloc', (tester) async {
    final router = await open(tester);
    queued.add(router.feed[0]);
    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(150, 0));
    await tester.pumpAndSettle();

    expect(router.current.name, 'Detail');
    expect(created, hasLength(2));
    expect(closed, [created.first]);
    expect(router.detail!.popGestureEnabled, isTrue);
    expect(find.byType(WallpaperDetailHero), findsNothing);
    unawaited(router.maybePop<void>());
    await tester.pumpAndSettle();
    expect(router.current.name, 'Grid');
    expect(closed, created);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final delay in [0, 16, 80]) {
    testWidgets('iOS pop ${delay}ms into first card switch does not fly the old wallpaper home', (tester) async {
      final router = await open(tester);
      queued.add(router.feed[2]);
      await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-150, 0));
      await tester.pump();
      await tester.pump(Duration(milliseconds: delay));
      final current = find.byWidgetPredicate((widget) => widget is WallpaperQuickActionRegion && widget.item.id == 'c');
      final before = tester.getRect(current);
      unawaited(router.maybePop<void>());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.getRect(current).width, closeTo(before.width, 0.01));
      await tester.pumpAndSettle();
      expect(router.current.name, 'Grid');
      expect(closed, created);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('each swiped wall loads, counts a view and taste once, and owns a recommendation session', (
    tester,
  ) async {
    await getIt.unregister<WallpaperDetailBloc>();
    final prism = _PrismRepository();
    final canonicalRequests = <String>[];
    when(() => prism.fetchCanonicalById(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      canonicalRequests.add(id);
      return Result.success((_item(id) as PrismFeedItem).wallpaper);
    });
    final palette = _PaletteRepository();
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('palette')));
    final stats = _StatsRepository();
    final views = <String>[];
    final oldView = Completer<Result<String>>();
    when(() => stats.recordWallpaperView(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.single as String;
      views.add(id);
      return id == 'B' ? oldView.future : Future.value(Result.success('200'));
    });
    when(() => stats.fetchWallpaperSetCount(any())).thenAnswer((_) async => Result.success<int?>(null));
    final recommendations = _Recommendations();
    final blocs = <WallpaperDetailBloc>[];
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = WallpaperDetailBloc(
        prism,
        _WallhavenRepository(),
        _PexelsRepository(),
        RecordPrismWallpaperViewsUsecase(stats),
        palette,
        GetWallpaperSetCountUseCase(stats),
        null,
        recommendations,
      );
      blocs.add(bloc);
      return bloc;
    });
    addTearDown(() async {
      if (!oldView.isCompleted) oldView.complete(Result.success('100'));
      for (final bloc in blocs) {
        if (!bloc.isClosed) await bloc.close();
      }
    });

    final router = await open(tester);
    expect(canonicalRequests, ['b']);
    expect(views, ['B']);
    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-150, 0));
    await tester.pumpAndSettle();

    expect(canonicalRequests, ['b', 'c']);
    expect(views, ['B', 'C']);
    expect(getIt<TasteSignalStore>().read().map((signal) => signal.creator), ['b', 'c']);
    expect(recommendations.visits.map((visit) => visit.wallId), ['b', 'c']);
    expect(recommendations.visits.map((visit) => visit.session).toSet(), hasLength(2));
    expect(recommendations.released, [recommendations.visits.first.session]);
    expect((blocs.last.state as WallpaperDetailLoaded).views, '200');

    oldView.complete(Result.success('100'));
    await tester.pump();
    expect((blocs.last.state as WallpaperDetailLoaded).entity.id, 'c');
    expect((blocs.last.state as WallpaperDetailLoaded).views, '200');
    expect(getIt<TasteSignalStore>().read().map((signal) => signal.creator), ['b', 'c']);

    unawaited(router.maybePop<void>());
    await tester.pumpAndSettle();
    await tester.pump();
    expect(recommendations.released, recommendations.visits.map((visit) => visit.session));
    expect(tester.takeException(), isNull);
  });
}
