import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/source_feed_grid.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/favourite_test_scope.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

FeedItemEntity _prismWall(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  ),
);

void main() {
  setUpFavouriteCounts();
  setUpAll(() {
    registerFallbackValue(const CategoryFeedEvent.started());
    registerFallbackValue(WallpaperDetailRoute());
  });
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  testWidgets('source grid feed keeps filtered tile indexes and excludes the see-more footer', (tester) async {
    const FeedItemEntity prism = FeedItemEntity.prism(
      id: 'prism-wall',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(id: 'prism-wall', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
      ),
    );
    const FeedItemEntity pexels = FeedItemEntity.pexels(
      id: 'pexels-wall',
      wallpaper: PexelsWallpaper(
        core: WallpaperCore(id: 'pexels-wall', source: WallpaperSource.pexels, fullUrl: '', thumbnailUrl: ''),
      ),
    );
    const FeedItemEntity wallhaven = FeedItemEntity.wallhaven(
      id: 'wallhaven-wall',
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(id: 'wallhaven-wall', source: WallpaperSource.wallhaven, fullUrl: '', thumbnailUrl: ''),
      ),
    );
    final CategoryFeedBloc bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(
      CategoryFeedState.initial().copyWith(
        status: LoadStatus.success,
        items: const <FeedItemEntity>[prism, pexels, wallhaven],
        hasMore: true,
      ),
    );
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<CategoryFeedBloc>.value(
            value: bloc,
            child: const Scaffold(
              body: SourceFeedGrid<WallhavenFeedItem>(
                surface: AnalyticsSurfaceValue.homeWallhavenGrid,
                listName: ScrollListNameValue.wallhavenGrid,
                sourceContextPrefix: 'test',
                includePrism: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PrismWallTile), findsNWidgets(2));
    await tester.tap(find.byType(PrismWallTile).last);
    await tester.pump();

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    final WallpaperFeed feed = route.args!.feed!;
    final List<PrismWallTile> renderedTiles = tester.widgetList<PrismWallTile>(find.byType(PrismWallTile)).toList();
    expect(feed.tiles.map((tile) => tile.item.id), <String>['prism-wall', 'wallhaven-wall']);
    expect(feed.tiles.map((tile) => tile.index), <int>[0, 1]);
    expect(feed.tiles.map((tile) => tile.heroTag), renderedTiles.map((tile) => tile.heroTag));
    expect(feed.indexOf(wallhaven), 1);
    expect(find.text('See more'), findsOneWidget);
  });

  testWidgets('source-feed return reveal uses the filtered live list index', (tester) async {
    final List<FeedItemEntity> items = List<FeedItemEntity>.generate(60, (index) => _prismWall('wall-$index'));
    final CategoryFeedState initial = CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      items: items,
      hasMore: false,
    );
    final StreamController<CategoryFeedState> states = StreamController<CategoryFeedState>.broadcast(sync: true);
    addTearDown(states.close);
    final CategoryFeedBloc bloc = _MockCategoryFeedBloc();
    whenListen(bloc, states.stream, initialState: initial);
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    tester.view.physicalSize = const Size(400, 450);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<CategoryFeedBloc>.value(
            value: bloc,
            child: const Scaffold(
              body: SourceFeedGrid<PrismFeedItem>(
                surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                listName: ScrollListNameValue.wallpaperGrid,
                sourceContextPrefix: 'test',
              ),
            ),
          ),
        ),
      ),
    );
    final Finder tappedTile = find.byKey(const ValueKey<String>('wall-15'));
    await tester.scrollUntilVisible(
      tappedTile,
      220,
      scrollable: find.descendant(of: find.byType(GridView), matching: find.byType(Scrollable)),
    );
    await tester.tap(tappedTile);
    await tester.pump();

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    final feed = route.args!.feed!;
    final Finder targetTile = find.byKey(const ValueKey<String>('wall-30'));
    states.add(initial.copyWith(items: items.skip(10).toList()));
    await tester.pump();
    await tester.pump();

    final Rect viewport = tester.getRect(find.byType(GridView));
    expect(feed.tiles.map((tile) => tile.item.id), items.map((item) => item.id));
    expect(_inside(viewport, tester.getRect(targetTile)), isFalse);
    feed.reveal(feed.indexOf(_prismWall('wall-30')));
    await tester.pump();

    expect(tester.getRect(targetTile).center.dy, closeTo(viewport.center.dy, 1));
  });
}

bool _inside(Rect viewport, Rect tile) =>
    tile.top >= viewport.top &&
    tile.bottom <= viewport.bottom &&
    tile.left >= viewport.left &&
    tile.right <= viewport.right;
