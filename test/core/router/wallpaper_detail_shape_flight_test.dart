import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';

class _DetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

FeedItemEntity _wall({int? width, int? height}) => FeedItemEntity.pexels(
  id: 'shape-wall',
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: 'shape-wall',
      source: WallpaperSource.pexels,
      fullUrl: '',
      thumbnailUrl: '',
      width: width,
      height: height,
    ),
  ),
);

WallpaperDetailLoaded _loaded(FeedItemEntity entity) => WallpaperDetailLoaded(
  entity: entity,
  paletteLoading: false,
  recommendations: const RecommendationState.exhausted(),
);

class _ShapeRouter extends RootStackRouter {
  _ShapeRouter(this.bloc, {this.useFeed = false, this.idOnly = false});

  final WallpaperDetailBloc bloc;
  final bool useFeed;
  final bool idOnly;
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
                tag: 'shape-tile',
                createRectTween: wallpaperHeroRectTween,
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
            if (useFeed) {
              return WallpaperDetailScreen(
                entity: _wall(),
                heroTag: 'shape-tile',
                feed: WallpaperFeed(grid: context, tiles: [(item: _wall(), index: 0, heroTag: 'shape-tile')]),
              ).wrappedRoute(context);
            }
            return BlocProvider<WallpaperDetailBloc>.value(
              value: bloc,
              child: idOnly
                  ? const WallpaperDetailScreen(
                      wallId: 'shape-wall',
                      source: WallpaperSource.pexels,
                      heroTag: 'shape-tile',
                    )
                  : WallpaperDetailScreen(entity: _wall(), heroTag: 'shape-tile'),
            );
          },
        ),
      ),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
  ];
}

Size _card(WidgetTester tester) => tester.getSize(find.byType(WallpaperDetailHero));

void main() {
  setUpFavouriteCounts();

  setUp(() {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
  });

  tearDown(() => getIt.reset());

  Future<({StreamController<WallpaperDetailState> states, _ShapeRouter router})> open(
    WidgetTester tester, {
    bool useFeed = false,
    bool idOnly = false,
    WallpaperDetailState? initial,
    Size viewport = const Size(400, 800),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final states = StreamController<WallpaperDetailState>();
    final bloc = _DetailBloc();
    whenListen(bloc, states.stream, initialState: initial ?? _loaded(_wall()));
    if (useFeed) getIt.registerFactory<WallpaperDetailBloc>(() => bloc);
    final router = _ShapeRouter(bloc, useFeed: useFeed, idOnly: idOnly);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await states.close();
      await bloc.close();
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
    for (var i = 0; i < 4 && find.byType(WallpaperDetailHero).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    return (states: states, router: router);
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform id-only loading to loaded keeps its actual Hero flight opaque and aligned', (tester) async {
      final (:states, :router) = await open(tester, idOnly: true, initial: const WallpaperDetailLoading());
      await tester.pump(const Duration(milliseconds: 40));
      expect(router.detail!.animation!.status, AnimationStatus.forward);
      final opened = _card(tester);
      final flight = find.byElementPredicate(
        (element) => element.widget is FadeTransition && ModalRoute.of(element) == null,
      );
      expect(flight, findsOneWidget);
      expect(tester.widget<FadeTransition>(flight).opacity.value, 1);
      states.add(_loaded(_wall(width: 1600, height: 900)));
      await tester.pump();
      await tester.pump();
      var frames = 0;
      while (router.detail!.animation!.isAnimating) {
        expect(flight, findsOneWidget);
        expect(
          tester.widget<FadeTransition>(flight).opacity.value,
          1,
          reason: 'loading to loaded must not abort or fade the actual Hero at flight frame $frames',
        );
        final art = tester.getRect(flight);
        final card = tester.getRect(find.byType(WallpaperDetailHero));
        expect(art.isEmpty, isFalse);
        expect(art.left, closeTo(card.left, 0.01));
        expect(art.top, closeTo(card.top, 0.01));
        expect(art.width, closeTo(card.width, 0.01));
        expect(tester.getRect(find.byType(WallpaperActionBar)).top, closeTo(card.bottom, 0.01));
        expect(_card(tester), opened);
        frames++;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(frames, greaterThan(3));
      expect(_card(tester), opened, reason: 'the loaded shape must not snap when the flight lands');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_card(tester).height, lessThan(opened.height));
      expect(_card(tester).height, greaterThan(_card(tester).width * 9 / 16));
      await tester.pumpAndSettle();
      expect(_card(tester).width / _card(tester).height, closeTo(16 / 9, 0.001));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));

    for (final useFeed in [false, true]) {
      final routeKind = useFeed ? 'feed' : 'single';
      testWidgets('$platform $routeKind size learned during entry waits until the Hero lands before easing', (
        tester,
      ) async {
        final (:states, :router) = await open(tester, useFeed: useFeed);
        await tester.pump(const Duration(milliseconds: 40));
        expect(router.detail!.animation!.status, AnimationStatus.forward);
        final opened = _card(tester);
        states.add(_loaded(_wall(width: 1600, height: 900)));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(_card(tester), opened, reason: 'the Hero destination must not resize during its flight');
        while (router.detail!.animation!.isAnimating) {
          expect(_card(tester), opened, reason: 'the destination must stay fixed through the last flight frame');
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(router.detail!.animation!.isCompleted, isTrue);
        expect(_card(tester), opened, reason: 'landing must not snap to the newly learned size');
        await tester.pump(const Duration(milliseconds: 100));
        expect(_card(tester).height, lessThan(opened.height));
        expect(_card(tester).height, greaterThan(_card(tester).width * 9 / 16));
        await tester.pumpAndSettle();
        expect(_card(tester).width / _card(tester).height, closeTo(16 / 9, 0.001));
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant({platform}));

      testWidgets('$platform $routeKind pop freezes a card size morph at the Hero departure size', (tester) async {
        final (:states, :router) = await open(tester, useFeed: useFeed);
        await tester.pumpAndSettle();
        final opened = _card(tester);
        states.add(_loaded(_wall(width: 1600, height: 900)));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final departing = _card(tester);
        expect(departing.height, lessThan(opened.height));
        expect(departing.height, greaterThan(departing.width * 9 / 16));
        expect(
          tester.widget<ProgressiveWallpaperImage>(find.byType(ProgressiveWallpaperImage)).decodeBox,
          isNull,
          reason: 'decoding uses the whole screen, never the changing displayed box',
        );
        unawaited(router.maybePop<void>());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(router.detail!.animation!.status, AnimationStatus.reverse);
        expect(_card(tester), departing, reason: 'the page must keep the size recorded by its departing Hero');
        await tester.pumpAndSettle();
        expect(router.current.name, 'Grid');
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant({platform}));
    }
  }

  testWidgets('iOS cancelling edge back eases to a size learned during the gesture', (tester) async {
    final (:states, :router) = await open(tester);
    await tester.pumpAndSettle();
    final paused = _card(tester);
    final gesture = await tester.startGesture(const Offset(1, 300));
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
    states.add(_loaded(_wall(width: 1600, height: 900)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_card(tester), paused, reason: 'the newly deferred target must wait for route settlement');
    await gesture.up();
    await tester.pump();
    while (router.detail!.animation!.isAnimating) {
      expect(_card(tester), paused, reason: 'gesture cancellation must settle before the morph resumes');
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(router.current.name, 'Detail');
    expect(_card(tester), paused, reason: 'cancelling back must not snap to the shape target');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_card(tester).height, lessThan(paused.height));
    expect(_card(tester).height, greaterThan(_card(tester).width * 9 / 16));
    await tester.pumpAndSettle();
    expect(_card(tester).width / _card(tester).height, closeTo(16 / 9, 0.001));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS cancelling edge back resumes an existing size morph from its current size', (tester) async {
    final (:states, :router) = await open(tester);
    await tester.pumpAndSettle();
    states.add(_loaded(_wall(width: 1600, height: 900)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_card(tester).height, inExclusiveRange(_card(tester).width * 9 / 16, 528));
    final gesture = await tester.startGesture(const Offset(1, 300));
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(router.navigatorKey.currentState!.userGestureInProgress, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    final released = _card(tester);
    await gesture.up();
    await tester.pump();
    expect(_card(tester), released, reason: 'releasing the gesture must not snap the card to its target');
    while (router.detail!.animation!.isAnimating) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(router.current.name, 'Detail');
    expect(_card(tester), released, reason: 'route settlement must resume from the currently shown size');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_card(tester).height, lessThan(released.height));
    expect(_card(tester).height, greaterThan(_card(tester).width * 9 / 16));
    await tester.pumpAndSettle();
    expect(_card(tester).width / _card(tester).height, closeTo(16 / 9, 0.001));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final shrinking in [false, true]) {
    final name = shrinking
        ? 'a canonical-loading feed swipe overlay stays on the clamped card when its viewport narrows'
        : 'a canonical-loading feed swipe overlay follows the shown card throughout viewport morph';
    testWidgets(name, (tester) async {
      final (:router, states: _) = await open(
        tester,
        useFeed: true,
        initial: const WallpaperDetailLoading(),
        viewport: shrinking ? const Size(800, 1000) : const Size(400, 800),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(router.detail!.animation!.isCompleted, isTrue);
      final opened = _card(tester);
      final overlay = find.byWidgetPredicate(
        (widget) =>
            widget is Positioned &&
            widget.child is Semantics &&
            (widget.child as Semantics).properties.label == 'Wallpaper',
      );
      expect(overlay, findsOneWidget);
      tester.view.physicalSize = shrinking ? const Size(400, 800) : const Size(800, 600);
      await tester.pump();
      await tester.pump();
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        final shown = tester.getRect(find.byType(WallpaperDetailHero));
        expect(tester.getRect(overlay), shown, reason: 'semantic bounds must match the displayed card at frame $frame');
        final drag = find.descendant(of: overlay, matching: find.byType(GestureDetector));
        expect(tester.getRect(drag), shown, reason: 'swipe hit bounds must match the displayed card at frame $frame');
        if (frame == 1) expect(_card(tester).height, inExclusiveRange(shrinking ? 528 : 396, opened.height));
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(_card(tester).height, shrinking ? 528 : 396);
      expect(tester.takeException(), isNull);
    });
  }
}
