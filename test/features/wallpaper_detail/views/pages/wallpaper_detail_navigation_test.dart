import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {
  final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>.broadcast(sync: true);
  final List<WallpaperDetailEvent> events = <WallpaperDetailEvent>[];
  void Function(WallpaperDetailEvent)? handleEvent;

  @override
  void add(WallpaperDetailEvent event) {
    events.add(event);
    handleEvent?.call(event);
  }
}

class _DetailTestRouter extends AppRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('DetailHostRoute', builder: (_) => const Scaffold(body: Text('detail host'))),
    ),
    AutoRoute(path: '/wallpaper-detail', page: WallpaperDetailRoute.page),
  ];
}

FeedItemEntity _prism(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
    title: id,
  ),
);

FeedItemEntity _wallhaven(String id) => FeedItemEntity.wallhaven(
  id: id,
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.wallhaven, fullUrl: '', thumbnailUrl: ''),
  ),
);

void main() {
  setUpFavouriteCounts();

  final List<_MockDetailBloc> blocs = <_MockDetailBloc>[];
  final List<WallpaperDetailState> initialStates = <WallpaperDetailState>[];

  setUp(() {
    blocs.clear();
    initialStates.clear();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = _MockDetailBloc();
      final initialState = initialStates.isEmpty ? const WallpaperDetailInitial() : initialStates.removeAt(0);
      whenListen(bloc, bloc.states.stream, initialState: initialState);
      blocs.add(bloc);
      return bloc;
    });
  });

  tearDown(() async {
    for (final bloc in blocs) {
      await bloc.states.close();
    }
    await getIt.reset();
  });

  Future<void> pumpTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<_DetailTestRouter> pumpRouter(WidgetTester tester, {PageRouteInfo? initialRoute}) async {
    final router = _DetailTestRouter();
    final config = router.config(deepLinkBuilder: initialRoute == null ? null : (_) => DeepLink.single(initialRoute));
    await tester.pumpWidget(
      MaterialApp.router(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: config,
      ),
    );
    if (initialRoute == null) {
      await router.navigatePath('/');
      await tester.pumpAndSettle();
    } else {
      await pumpTransition(tester);
    }
    return router;
  }

  Future<void> disposeRouter(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('A loads page two and tint, opens recommendation B then A again, and pops restore each visit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final a = _wallhaven('A');
    final b = _wallhaven('B');
    final firstPage = [for (var i = 0; i < 12; i++) _prism('first-$i')];
    final secondPage = [b, for (var i = 0; i < 8; i++) _prism('second-$i')];
    var aState = WallpaperDetailLoaded(
      entity: a,
      paletteLoading: false,
      colors: const [Colors.red, Colors.blue],
      accent: Colors.red,
      recommendations: RecommendationState(
        items: firstPage,
        kind: RecommendationKind.related,
        status: RecommendationStatus.ready,
        cursor: const ExternalRecommendationCursor(2),
      ),
    );
    initialStates.addAll([
      aState,
      WallpaperDetailLoaded(
        entity: b,
        paletteLoading: false,
        recommendations: RecommendationState(
          items: [a],
          kind: RecommendationKind.related,
          status: RecommendationStatus.exhausted,
        ),
      ),
      WallpaperDetailLoaded(entity: a, paletteLoading: false, recommendations: const RecommendationState.exhausted()),
    ]);
    final router = await pumpRouter(tester);
    unawaited(router.push<void>(WallpaperDetailRoute(entity: a)));
    await tester.pumpAndSettle();
    final firstVisit = blocs.single;
    firstVisit.handleEvent = (event) {
      if (event is SelectAccentColor) {
        aState = aState.copyWith(accent: Colors.blue, colorChanged: true);
        firstVisit.states.add(aState);
      } else if (event is LoadRecommendations) {
        aState = aState.copyWith(
          recommendations: aState.recommendations.append(
            RecommendationPage(items: secondPage, kind: RecommendationKind.related),
            a,
          ),
        );
        firstVisit.states.add(aState);
      }
    };
    firstVisit.add(const SelectAccentColor(color: Colors.blue));
    await tester.pumpAndSettle();
    expect((firstVisit.state as WallpaperDetailLoaded).tint, Colors.blue);
    final bTile = find.byKey(ValueKey((WallpaperSource.wallhaven, 'B')));
    await tester.scrollUntilVisible(bTile, 500, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(
      (firstVisit.state as WallpaperDetailLoaded).recommendations.items.map((item) => item.id),
      [...firstPage, ...secondPage].map((item) => item.id),
    );
    expect(firstVisit.events.whereType<LoadRecommendations>(), hasLength(1));
    final firstController = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    final firstOffset = firstController.offset;
    final bHero = tester
        .widget<PrismWallTile>(find.descendant(of: bTile, matching: find.byType(PrismWallTile)))
        .heroTag;
    await tester.tap(bTile);
    await tester.pumpAndSettle();
    expect(blocs, hasLength(2));
    expect((blocs[1].state as WallpaperDetailLoaded).entity.id, 'B');
    expect(router.current.argsAs<WallpaperDetailRouteArgs>().heroTag, bHero);
    final secondController = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    await tester.scrollUntilVisible(
      find.byKey(ValueKey((WallpaperSource.wallhaven, 'A'))),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ValueKey((WallpaperSource.wallhaven, 'A'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey((WallpaperSource.wallhaven, 'A'))));
    await tester.pumpAndSettle();
    expect(blocs, hasLength(3));
    expect(blocs[2], isNot(same(firstVisit)));
    expect((blocs[2].state as WallpaperDetailLoaded).tint, isNull);
    expect(tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!.offset, 0);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller, same(secondController));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!.offset, firstOffset);
    expect((firstVisit.state as WallpaperDetailLoaded).tint, Colors.blue);
    expect(
      (firstVisit.state as WallpaperDetailLoaded).recommendations.items.map((item) => item.id),
      [...firstPage, ...secondPage].map((item) => item.id),
    );
    expect(firstVisit.events.whereType<LoadFromEntity>(), hasLength(1));
    expect(firstVisit.events.whereType<LoadRecommendations>(), hasLength(1));
    await disposeRouter(tester);
  });

  testWidgets('pushed detail routes get isolated blocs and pop restores the covered wallpaper', (tester) async {
    initialStates.addAll(<WallpaperDetailState>[
      WallpaperDetailLoaded(recommendations: const RecommendationState.exhausted(), entity: _prism('FIRST')),
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _wallhaven('SECOND'),
        panelCollapsed: false,
      ),
    ]);
    final router = await pumpRouter(tester);

    unawaited(router.push<void>(WallpaperDetailRoute(entity: _prism('FIRST'))));
    await tester.pumpAndSettle();
    expect(find.text('FIRST'), findsOneWidget);
    expect(find.text('Prism'), findsOneWidget);

    unawaited(router.push<void>(WallpaperDetailRoute(entity: _wallhaven('SECOND'))));
    await tester.pumpAndSettle();
    expect(blocs, hasLength(2));
    expect(blocs[0], isNot(same(blocs[1])));
    expect(blocs[0].events.single, isA<LoadFromEntity>());
    expect(blocs[1].events.single, isA<LoadFromEntity>());
    expect(find.text('SECOND'), findsOneWidget);
    expect(find.text('Wallhaven'), findsNWidgets(2));

    router.pop<void>();
    await tester.pumpAndSettle();
    expect(find.text('FIRST'), findsOneWidget);
    expect(find.text('Prism'), findsOneWidget);
    expect(find.text('SECOND'), findsNothing);
    await disposeRouter(tester);
  });

  testWidgets('navigating the same detail route to a wallId reloads even when the id is unchanged', (tester) async {
    const id = 'SAME-ID';
    initialStates.add(
      WallpaperDetailLoaded(recommendations: const RecommendationState.exhausted(), entity: _prism(id)),
    );
    final router = await pumpRouter(tester);

    unawaited(router.push(WallpaperDetailRoute(entity: _prism(id))));
    await tester.pumpAndSettle();
    expect(find.text('Prism'), findsOneWidget);

    await router.navigate(WallpaperDetailRoute(wallId: id, source: WallpaperSource.wallhaven));
    await pumpTransition(tester);

    expect(router.current.name, WallpaperDetailRoute.name);
    expect(blocs, hasLength(2));
    final loadEvent = blocs[1].events.single as LoadFromId;
    expect(loadEvent.wallId, id);
    expect(loadEvent.source, WallpaperSource.wallhaven);
    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('Prism'), findsNothing);

    blocs[1].states.add(
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _wallhaven(id),
        panelCollapsed: false,
      ),
    );
    await tester.pump();
    expect(find.text('Wallhaven'), findsNWidgets(2));

    await router.navigate(WallpaperDetailRoute(wallId: 'OTHER-ID', source: WallpaperSource.wallhaven));
    await pumpTransition(tester);
    expect(blocs, hasLength(3));
    expect((blocs[2].events.single as LoadFromId).wallId, 'OTHER-ID');

    blocs[2].states.add(
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _wallhaven('OTHER-ID'),
        panelCollapsed: false,
      ),
    );
    await tester.pump();
    expect(find.text('OTHER-ID'), findsOneWidget);

    await router.navigate(WallpaperDetailRoute(wallId: 'OTHER-ID', source: WallpaperSource.wallhaven));
    await pumpTransition(tester);
    expect(blocs, hasLength(3));
    await disposeRouter(tester);
  });

  testWidgets('wallId-only routes show loading then render the fetched wallpaper', (tester) async {
    final router = await pumpRouter(
      tester,
      initialRoute: WallpaperDetailRoute(wallId: 'FETCHED', source: WallpaperSource.wallhaven),
    );

    expect(router.current.name, WallpaperDetailRoute.name);
    expect(blocs.single.events.single, isA<LoadFromId>());
    expect(find.byType(GlintState), findsOneWidget);
    blocs.single.states.add(
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _wallhaven('FETCHED'),
        panelCollapsed: false,
      ),
    );
    await tester.pump();
    expect(find.text('FETCHED'), findsOneWidget);
    expect(find.text('Wallhaven'), findsNWidgets(2));
    await disposeRouter(tester);
  });

  testWidgets('wallId-only routes render fetch errors', (tester) async {
    final router = await pumpRouter(
      tester,
      initialRoute: WallpaperDetailRoute(wallId: 'MISSING', source: WallpaperSource.pexels),
    );

    expect(router.current.name, WallpaperDetailRoute.name);
    expect(find.byType(GlintState), findsOneWidget);
    blocs.single.states.add(const WallpaperDetailError(failure: WallpaperDetailLoadFailure.notFound));
    await tester.pump();
    expect(find.text("Couldn't load this wallpaper"), findsOneWidget);
    expect(find.text('Wallpaper not found'), findsOneWidget);
    await disposeRouter(tester);
  });
}
