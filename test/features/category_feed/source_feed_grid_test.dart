import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/source_feed_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

void main() {
  setUpAll(() => registerFallbackValue(const CategoryFeedEvent.started()));
  setUp(() => getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore())));
  tearDown(getIt.reset);

  const item = FeedItemEntity.prism(
    id: 'last-wallpaper',
    wallpaper: PrismWallpaper(
      core: WallpaperCore(id: 'last-wallpaper', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
    ),
  );

  const space = CategoryEntity(
    name: 'Space',
    source: WallpaperSource.prism,
    searchType: CategorySearchType.nonSearch,
    image: '',
    image2: '',
  );

  /// A bloc that settles as soon as it is asked to reload, like a reload that finishes.
  _MockCategoryFeedBloc streamedBloc(CategoryFeedState state) {
    final bloc = _MockCategoryFeedBloc();
    final controller = StreamController<CategoryFeedState>.broadcast(sync: true);
    addTearDown(controller.close);
    whenListen(bloc, controller.stream, initialState: state);
    when(() => bloc.add(any())).thenAnswer((_) => controller.add(state.copyWith(status: LoadStatus.success)));
    return bloc;
  }

  Widget host(_MockCategoryFeedBloc bloc) => MaterialApp(
    home: BlocProvider<CategoryFeedBloc>.value(
      value: bloc,
      child: const SourceFeedGrid<FeedItemEntity>(
        surface: AnalyticsSurfaceValue.homeWallpaperGrid,
        listName: ScrollListNameValue.wallpaperGrid,
        sourceContextPrefix: 'test',
      ),
    ),
  );

  Future<void> pumpGrid(WidgetTester tester, CategoryFeedState state) async {
    final bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CategoryFeedBloc>.value(
          value: bloc,
          child: SourceFeedGrid<PrismFeedItem>(
            surface: AnalyticsSurfaceValue.homeWallpaperGrid,
            listName: ScrollListNameValue.wallpaperGrid,
            sourceContextPrefix: 'test',
            itemWrapper: (context, item, tile) => Text(item.id),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the skeleton grid while the first page loads', (tester) async {
    await pumpGrid(tester, CategoryFeedState.initial());

    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.byType(GlintState), findsNothing);
  });

  testWidgets('a successful empty feed shows an empty state, not skeletons', (tester) async {
    await pumpGrid(tester, CategoryFeedState.initial().copyWith(status: LoadStatus.success, hasMore: false));

    expect(find.text('No wallpapers here yet'), findsOneWidget);
    expect(find.byType(LoadingCards), findsNothing);
  });

  testWidgets('a failed next page shows a retry footer that asks for the page again', (tester) async {
    final bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(
      CategoryFeedState.initial().copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.failure,
        items: const <FeedItemEntity>[item],
        hasMore: true,
      ),
    );
    final favourites = _MockFavouriteWallsBloc();
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<CategoryFeedBloc>.value(value: bloc),
            BlocProvider<FavouriteWallsBloc>.value(value: favourites),
          ],
          child: const SourceFeedGrid<PrismFeedItem>(
            surface: AnalyticsSurfaceValue.homeWallpaperGrid,
            listName: ScrollListNameValue.wallpaperGrid,
            sourceContextPrefix: 'test',
          ),
        ),
      ),
    );

    await tester.tap(find.text("Couldn't load more. Tap to retry"));

    verify(() => bloc.add(const CategoryFeedEvent.fetchMoreRequested())).called(1);
  });

  testWidgets('shows an empty state with a refresh when a loaded feed has no wallpapers', (tester) async {
    final bloc = streamedBloc(
      CategoryFeedState.initial().copyWith(status: LoadStatus.success, selectedCategory: space),
    );

    await tester.pumpWidget(host(bloc));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, 'No wallpapers here yet'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    verify(() => bloc.add(const CategoryFeedEvent.refreshRequested())).called(1);
  });

  testWidgets('shows an error with Try again when the feed failed and has no wallpapers', (tester) async {
    final bloc = streamedBloc(
      CategoryFeedState.initial().copyWith(status: LoadStatus.failure, selectedCategory: space),
    );

    await tester.pumpWidget(host(bloc));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, "Couldn't load wallpapers"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    verify(() => bloc.add(const CategoryFeedEvent.refreshRequested())).called(1);
  });

  testWidgets('keeps the final wallpaper when the feed has no more pages', (tester) async {
    await pumpGrid(tester, CategoryFeedState.initial().copyWith(items: const <FeedItemEntity>[item], hasMore: false));

    expect(find.text('last-wallpaper'), findsOneWidget);
    expect(find.text('See more'), findsNothing);
  });

  testWidgets('appends See more after all wallpapers when another page exists', (tester) async {
    await pumpGrid(tester, CategoryFeedState.initial().copyWith(items: const <FeedItemEntity>[item], hasMore: true));

    expect(find.text('last-wallpaper'), findsOneWidget);
    expect(find.text('See more'), findsOneWidget);
  });

  group('a Wallhaven category that starts with Prism walls', () {
    const wallhavenItem = FeedItemEntity.wallhaven(
      id: 'wh-1',
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(id: 'wh-1', source: WallpaperSource.wallhaven, fullUrl: '', thumbnailUrl: ''),
      ),
    );

    Future<void> pumpMixed(WidgetTester tester, {required bool includePrism}) async {
      final bloc = _MockCategoryFeedBloc();
      when(() => bloc.state).thenReturn(
        CategoryFeedState.initial().copyWith(
          status: LoadStatus.success,
          items: const <FeedItemEntity>[item, wallhavenItem],
          hasMore: false,
        ),
      );
      final favourites = _MockFavouriteWallsBloc();
      when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<CategoryFeedBloc>.value(value: bloc),
              BlocProvider<FavouriteWallsBloc>.value(value: favourites),
            ],
            child: SourceFeedGrid<WallhavenFeedItem>(
              surface: AnalyticsSurfaceValue.homeWallhavenGrid,
              listName: ScrollListNameValue.wallhavenGrid,
              sourceContextPrefix: 'test',
              includePrism: includePrism,
            ),
          ),
        ),
      );
    }

    testWidgets('shows the Prism walls ahead of the Wallhaven walls, with the Prism-first source context', (
      tester,
    ) async {
      await pumpMixed(tester, includePrism: true);

      final tiles = tester.widgetList<WallpaperTile>(find.byType(WallpaperTile)).toList();
      expect(tiles.map((tile) => tile.item.id), <String>['last-wallpaper', 'wh-1']);
      expect(tiles.map((tile) => tile.sourceContext), <String?>['category_prism_first', null]);
      expect(tiles.every((tile) => tile.quickActions), isTrue);
    });

    testWidgets('without the flag a Wallhaven grid still hides other sources', (tester) async {
      await pumpMixed(tester, includePrism: false);

      expect(tester.widgetList<WallpaperTile>(find.byType(WallpaperTile)).map((tile) => tile.item.id), <String>[
        'wh-1',
      ]);
    });
  });
}
