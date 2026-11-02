import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/favourite_test_scope.dart';
import 'support/fav_fixtures.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

class _MockSetFavouritePinUseCase extends Mock implements SetFavouritePinUseCase {}

class _MockStackRouter extends Mock implements StackRouter {}

void main() {
  setUpFavouriteCounts();
  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late FavouriteWallsBloc bloc;
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'user_1'));
    registerFallbackValue(WallpaperDetailRoute());
  });

  setUp(() {
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => Result.success(<FavouriteWallEntity>[
        prismFav('valid'),
        const LegacyFavouriteWall(
          id: 'legacy',
          source: WallpaperSource.prism,
          legacyPayload: <String, Object?>{'url': 'https://example.com/legacy.jpg'},
        ),
      ]),
    );
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  FavouriteWallsBloc createBloc() {
    bloc = FavouriteWallsBloc(
      fetchUseCase,
      _MockToggleFavouriteWallUseCase(),
      _MockClearFavouriteWallsUseCase(),
      _MockSetFavouritePinUseCase(),
    );
    addTearDown(bloc.close);
    return bloc;
  }

  testWidgets('opening a favourite swipes only across convertible visible favourites', (tester) async {
    createBloc();
    bloc.add(
      FavouriteWallsEvent.synced(
        userId: 'user_1',
        items: <FavouriteWallEntity>[
          prismFav('valid'),
          const LegacyFavouriteWall(
            id: 'legacy',
            source: WallpaperSource.prism,
            legacyPayload: <String, Object?>{'url': 'https://example.com/legacy.jpg'},
          ),
          prismFav('second'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Widget buildApp() => MaterialApp(
      builder: favouriteTestBuilder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: const Scaffold(body: FavouriteGrid()),
        ),
      ),
    );
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump();

    expect(bloc.state.status, LoadStatus.success);
    await tester.tap(find.byKey(const ValueKey<String>('valid')));
    await tester.pump();

    final captured = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    final feed = captured.args!.feed!;
    expect(feed.tiles.map((tile) => tile.item.id), <String>['valid', 'second']);
    expect(feed.tiles.map((tile) => tile.index), <int>[0, 2]);
    expect(feed.tiles.every((tile) => tile.item is PrismFeedItem), isTrue);
    // The tapped wall is at grid index 0, so its tag matches the route's own heroTag.
    expect(feed.tiles.first.heroTag, captured.args!.heroTag);
    expect(feed.tiles.last.heroTag, isNot(feed.tiles.first.heroTag));
  });

  testWidgets('a surviving favourite keeps its hero tag when an earlier favourite is removed', (tester) async {
    createBloc();
    final List<FavouriteWallEntity> items = List<FavouriteWallEntity>.generate(8, (index) => prismFav('wall-$index'));
    bloc.add(FavouriteWallsEvent.synced(userId: 'user_1', items: items));
    await tester.pump();
    await tester.pump();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Widget buildApp() => MaterialApp(
      builder: favouriteTestBuilder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: const Scaffold(body: FavouriteGrid()),
        ),
      ),
    );
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('wall-1')));
    await tester.pump();

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    final feed = route.args!.feed!;
    final String targetTag = feed.tiles.singleWhere((tile) => tile.item.id == 'wall-3').heroTag;
    final Finder targetTile = find.byKey(const ValueKey<String>('wall-3'));
    expect(_heroTag(tester, targetTile), targetTag);

    bloc.add(FavouriteWallsEvent.synced(userId: 'user_1', items: items.skip(1).toList()));
    await tester.pump();
    await tester.pump();

    expect(feed.tiles.map((tile) => tile.item.id), items.map((wall) => wall.id));
    expect(bloc.state.visibleItems.map((wall) => wall.id), items.skip(1).map((wall) => wall.id));
    expect(BlocProvider.of<FavouriteWallsBloc>(tester.element(find.byType(FavouriteGrid))), same(bloc));
    expect(
      (tester.widget<GridView>(find.byType(GridView)).childrenDelegate as SliverChildBuilderDelegate).childCount,
      items.length - 1,
    );
    expect(find.byKey(const ValueKey<String>('wall-0')), findsNothing);
    expect(_heroTag(tester, targetTile), targetTag);
  });

  testWidgets('return reveal uses the surviving favourite current grid index after removal', (tester) async {
    createBloc();
    final List<FavouriteWallEntity> items = List<FavouriteWallEntity>.generate(60, (index) => prismFav('wall-$index'));
    bloc.add(FavouriteWallsEvent.synced(userId: 'user_1', items: items));
    await tester.pump();
    await tester.pump();
    tester.view.physicalSize = const Size(400, 450);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget buildApp() => MaterialApp(
      builder: favouriteTestBuilder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: const Scaffold(body: FavouriteGrid()),
        ),
      ),
    );
    await tester.pumpWidget(buildApp());
    await tester.pump();
    final Finder tappedTile = find.byKey(const ValueKey<String>('wall-15'));
    await tester.scrollUntilVisible(
      tappedTile,
      220,
      scrollable: find.descendant(of: find.byType(GridView), matching: find.byType(Scrollable)),
    );
    await tester.pump();
    await tester.tap(tappedTile);
    await tester.pump();

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    final feed = route.args!.feed!;
    final int stalePosition = feed.indexOf(prismFav('wall-30').toFeedItem());
    final Finder targetTile = find.byKey(const ValueKey<String>('wall-30'));
    bloc.add(FavouriteWallsEvent.synced(userId: 'user_1', items: items.skip(10).toList()));
    await tester.pump();
    await tester.pump();

    final Rect viewport = tester.getRect(find.byType(GridView));
    expect(bloc.state.visibleItems.map((wall) => wall.id), items.skip(10).map((wall) => wall.id));
    expect(feed.tiles.map((tile) => tile.item.id), items.map((wall) => wall.id));
    expect(feed.tiles[stalePosition].index, 30);
    expect(bloc.state.visibleItems.indexWhere((wall) => wall.id == 'wall-30'), 20);
    expect(targetTile.evaluate().isEmpty || !_inside(viewport, tester.getRect(targetTile)), isTrue);
    feed.reveal(stalePosition);
    await tester.pump();

    expect(targetTile, findsOneWidget);
    expect(tester.getRect(targetTile).center.dy, closeTo(viewport.center.dy, 1));
  });
}

String _heroTag(WidgetTester tester, Finder tile) =>
    tester.widget<Hero>(find.descendant(of: tile, matching: find.byType(Hero))).tag as String;

bool _inside(Rect viewport, Rect tile) =>
    tile.top >= viewport.top &&
    tile.bottom <= viewport.bottom &&
    tile.left >= viewport.left &&
    tile.right <= viewport.right;
