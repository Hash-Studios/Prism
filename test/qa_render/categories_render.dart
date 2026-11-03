@Tags(<String>['qa_render'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_grid.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_feed_cache_local_data_source.dart';
import '../support/fake_firestore_client.dart';
import '../support/fake_user_block_repository.dart';
import '../support/in_memory_local_store.dart';
import 'home_render_support.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _MockFavouriteCountsCubit extends MockCubit<Map<String, PrismWallpaperStats>> implements FavouriteCountsCubit {}

class _MockFavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

/// Every built-in category, with Desktop's cover on a local photo. Desktop is hidden from the grid scene by default.
List<CategoryEntity> _categories({required bool includeDesktop}) => <CategoryEntity>[
  for (final CategoryDefinition definition in categoryDefinitions)
    if (includeDesktop || definition.name != 'Desktop')
      CategoryEntity(
        name: definition.name,
        source: definition.source,
        searchType: definition.searchType,
        image: definition.name == 'Desktop' ? photoUrl('desktop-2-wide.jpg') : definition.imageUrl,
        image2: definition.secondaryImageUrl,
        hasPrismWalls: definition.hasPrismWalls,
        query: definition.query,
      ),
];

/// Twenty-four provider photos of one category, named `<prefix>-01.jpg` to `<prefix>-24.jpg` in the photo folder.
List<FeedItemEntity> _pexelsItems(String prefix) => <FeedItemEntity>[
  for (int i = 1; i <= 24; i++)
    FeedItemEntity.pexels(
      id: '$prefix-$i',
      wallpaper: PexelsWallpaper(
        core: WallpaperCore(
          id: '$prefix-$i',
          source: WallpaperSource.pexels,
          fullUrl: photoUrl('$prefix-${i.toString().padLeft(2, '0')}.jpg'),
          thumbnailUrl: photoUrl('$prefix-${i.toString().padLeft(2, '0')}.jpg'),
          authorName: 'Photographer $i',
          width: 2000,
          height: 3000,
        ),
      ),
    ),
];

/// The six Prism walls that have a desktop companion, read from the manifest in the photo folder.
List<FeedItemEntity> _desktopItems() {
  final Map<String, Object?> manifest =
      (jsonDecode(File('$_photoFolder/manifest.json').readAsStringSync()) as Map<Object?, Object?>).cast();
  final List<Map<String, Object?>> walls = <Map<String, Object?>>[
    for (final Object? entry in manifest['desktop']! as List<Object?>)
      (entry! as Map<Object?, Object?>).cast<String, Object?>(),
  ];
  return <FeedItemEntity>[
    for (final Map<String, Object?> wall in walls)
      FeedItemEntity.prism(
        id: wall['id']! as String,
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: wall['id']! as String,
            source: WallpaperSource.prism,
            fullUrl: photoUrl(wall['wide']! as String),
            thumbnailUrl: photoUrl(wall['file']! as String),
            authorName: 'Studio',
            width: 1080,
            height: 2340,
          ),
          title: wall['title']! as String,
          desktop: WallDesktopVariant.parse(<String, Object?>{
            ...(wall['desktopVariant']! as Map<Object?, Object?>).cast<String, Object?>(),
            'thumb': photoUrl(wall['wide']! as String),
          }),
        ),
      ),
  ];
}

String get _photoFolder => Platform.environment['QA_PHOTOS'] ?? '/tmp/prism-qa/categories-photos';

CategoryFeedState _feedState({required String selected, required List<FeedItemEntity> items, bool desktop = true}) {
  final List<CategoryEntity> categories = _categories(includeDesktop: desktop);
  return CategoryFeedState.initial().copyWith(
    status: LoadStatus.success,
    categories: categories,
    selectedCategory: categories.firstWhere((CategoryEntity c) => c.name == selected),
    items: items,
  );
}

_MockCategoryFeedBloc _bloc(CategoryFeedState state) {
  final _MockCategoryFeedBloc bloc = _MockCategoryFeedBloc();
  // Each listener gets the state at once, so the page's wait for a settled state never stays open.
  whenListen(
    bloc,
    Stream<CategoryFeedState>.multi((StreamController<CategoryFeedState> controller) => controller.add(state)),
    initialState: state,
  );
  return bloc;
}

Future<void> _pump(
  WidgetTester tester,
  HomeShot shot,
  ThemeData theme,
  MockStackRouter router,
  CategoryFeedBloc bloc,
  Widget page, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final _MockFavouriteBloc favourites = _MockFavouriteBloc();
  whenListen(favourites, const Stream<FavouriteWallsState>.empty(), initialState: FavouriteWallsState.initial());
  await tester.pumpWidget(
    shot.frame(
      brightness: theme.brightness,
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<FavouriteWallsBloc>.value(
            value: favourites,
            child: BlocProvider<CategoryFeedBloc>.value(value: bloc, child: page),
          ),
        ),
      ),
    ),
  );
}

Future<void> _save(WidgetTester tester, HomeShot shot, String name, Brightness brightness) async {
  final RenderRepaintBoundary render = shot.boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final String mode = brightness == Brightness.light ? 'light' : 'dark';
  final File file = File('build/qa_render/categories/${name}_$mode.png');
  await tester.runAsync(() async {
    final ui.Image image = await render.toImage(pixelRatio: 3);
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    registerFallbackValue(const CategoryFeedEvent.started());
    if (homeRender) await loadAppFonts();
  });

  final List<(String, ThemeData)> themes = <(String, ThemeData)>[('light', kLightTheme), ('dark', kDarkTheme)];

  /// One scene in both themes. The photo cache answers every cover and tile with a real photo.
  void scene(
    String name,
    Future<void> Function(WidgetTester tester, HomeShot shot, ThemeData theme, MockStackRouter router) body,
  ) {
    for (final (String mode, ThemeData theme) in themes) {
      testWidgets('$name ($mode)', skip: !homeRender, (WidgetTester tester) async {
        final HomeShot shot = HomeShot(tester)..configureView();
        QaPhotoCache.install();
        AnalyticsRuntime.instance = FakeAppAnalytics();
        getIt.registerSingleton<FirestoreClient>(FakeFirestoreClient());
        final _MockFavouriteCountsCubit counts = _MockFavouriteCountsCubit();
        whenListen(
          counts,
          const Stream<Map<String, PrismWallpaperStats>>.empty(),
          initialState: const <String, PrismWallpaperStats>{},
        );
        getIt.registerSingleton<FavouriteCountsCubit>(counts);
        getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
        getIt.registerSingleton<FeedCacheLocalDataSource>(FakeFeedCacheLocalDataSource());
        getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
        getIt.registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending()..completeInitial(<String>{}));
        final MockStackRouter router = MockStackRouter();
        addTearDown(() async {
          QaPhotoCache.uninstall();
          AnalyticsRuntime.reset();
          await getIt.reset();
        });
        await body(tester, shot, theme, router);
        await _save(tester, shot, name, theme.brightness);
        // flutter_cache_manager schedules a 10 s cleanup on first use, which would fail the test as a pending timer.
        await tester.pump(const Duration(seconds: 11));
        expect(tester.takeException(), isNull);
      });
    }
  }

  scene('grid', (WidgetTester tester, HomeShot shot, ThemeData theme, MockStackRouter router) async {
    final CategoryFeedBloc bloc = _bloc(
      _feedState(selected: 'AI Art', items: const <FeedItemEntity>[], desktop: false),
    );
    await _pump(tester, shot, theme, router, bloc, const Scaffold(body: CollectionsGrid()));
    await shot.settle(frames: 12);
  });

  scene('grid_large_text', (WidgetTester tester, HomeShot shot, ThemeData theme, MockStackRouter router) async {
    final CategoryFeedBloc bloc = _bloc(
      _feedState(selected: 'AI Art', items: const <FeedItemEntity>[], desktop: false),
    );
    await _pump(
      tester,
      shot,
      theme,
      router,
      bloc,
      const Scaffold(body: CollectionsGrid()),
      textScaler: const TextScaler.linear(2.0),
    );
    await shot.settle(frames: 12);
  });

  scene('grid_with_desktop', (WidgetTester tester, HomeShot shot, ThemeData theme, MockStackRouter router) async {
    final CategoryFeedBloc bloc = _bloc(_feedState(selected: 'AI Art', items: const <FeedItemEntity>[]));
    await _pump(tester, shot, theme, router, bloc, const Scaffold(body: CollectionsGrid()));
    await shot.settle(frames: 12);
    await tester.scrollUntilVisible(find.text('Desktop'), 300, scrollable: find.byType(Scrollable).first);
    await shot.scrollBy(150);
    await shot.settle(frames: 12);
  });

  void pageScene(String name, String category, List<FeedItemEntity> items, {TextScaler scale = TextScaler.noScaling}) {
    scene(name, (WidgetTester tester, HomeShot shot, ThemeData theme, MockStackRouter router) async {
      final CategoryFeedBloc bloc = _bloc(_feedState(selected: category, items: items));
      await _pump(
        tester,
        shot,
        theme,
        router,
        bloc,
        CollectionViewScreen(collectionName: 'category:${Uri.encodeComponent(category)}'),
        textScaler: scale,
      );
      await shot.settle(frames: 16);
    });
  }

  pageScene('page_pastel', 'Pastel', _pexelsItems('pastel'));
  pageScene('page_gaming', 'Gaming', _pexelsItems('gaming'));
  pageScene('page_3d_render', '3D Render', _pexelsItems('render3d'));
  pageScene('page_desktop', 'Desktop', _desktopItems());
  pageScene('page_pastel_large_text', 'Pastel', _pexelsItems('pastel'), scale: const TextScaler.linear(2.0));
}
