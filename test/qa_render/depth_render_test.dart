@Tags(<String>['qa_render'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/depth_tag.dart';
import 'package:Prism/core/widgets/prism/prism_toast.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/trending/views/widgets/boosted_tag.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_app_analytics.dart';
import '../support/in_memory_local_store.dart';
import 'home_render_support.dart';

class _MockFavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

String get _outDir => Platform.environment['QA_OUT'] ?? '/tmp/prism-qa/depth-renders';

PrismWallpaper _wall(int n, WallDepthTier? tier, {bool boosted = false, bool premium = false}) {
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
      resolution: '1440x3120',
      sizeBytes: 2400000,
      createdAt: DateTime(2026, 10, 12),
    ),
    title: 'Wall $n',
    collections: premium ? const <String>['space'] : null,
    tags: const <String>['mountain', 'night', 'portrait'],
    boostedUntil: boosted ? DateTime.now().add(const Duration(hours: 3)) : null,
    depthTier: tier,
  );
}

/// One render: the iOS platform, an iPhone 15 sized view, real fonts and real photos.
class _Depth {
  _Depth(this.tester, this.theme) : shot = HomeShot(tester);

  final WidgetTester tester;
  final ThemeData theme;
  final HomeShot shot;
  final MockStackRouter router = MockStackRouter();

  Future<void> setUp() async {
    shot.configureView();
    QaPhotoCache.install();
    PrismFullImageCache.testOverride = PrismImageCache.testOverride;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'me'
      ..loggedIn = true;
    final FavoritesLocalDataSource favourites = FavoritesLocalDataSource(InMemoryLocalStore());
    await favourites.setWallFavourite('me', 'qa1', true);
    await favourites.setWallFavourite('me', 'qa4', true);
    getIt
      ..registerSingleton<FavoritesLocalDataSource>(favourites)
      ..registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    when(() => router.push(any())).thenAnswer((_) async => null);
  }

  Future<void> mount(Widget home) async {
    final _MockFavouriteBloc favourites = _MockFavouriteBloc();
    whenListen(
      favourites,
      const Stream<FavouriteWallsState>.empty(),
      initialState: FavouriteWallsState.initial().copyWith(status: LoadStatus.success, userId: 'me'),
    );
    await tester.pumpWidget(
      shot.frame(
        brightness: theme.brightness,
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: BlocProvider<FavouriteWallsBloc>.value(
            value: favourites,
            child: StackRouterScope(controller: router, stateHash: 0, child: home),
          ),
        ),
      ),
    );
    await shot.settle(frames: 10);
  }

  /// Six tiles of the home grid: auto, menu, none and unchecked walls, with the Boosted tag, the premium star and the
  /// favourite heart on some of them.
  Future<void> pumpGrid() async {
    final List<PrismWallpaper> walls = <PrismWallpaper>[
      _wall(1, WallDepthTier.auto, boosted: true),
      _wall(2, WallDepthTier.menu, premium: true),
      _wall(3, WallDepthTier.none),
      _wall(4, WallDepthTier.menu),
      _wall(5, null, premium: true),
      _wall(6, WallDepthTier.auto, premium: true),
    ];
    await mount(
      Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: <Widget>[
                const SliverToBoxAdapter(child: PrismHeader(title: 'Mountains', showBack: false)),
                SliverPadding(
                  padding: PrismFeedLayout.gridPadding,
                  sliver: SliverGrid(
                    gridDelegate: PrismWallGrid.delegate(context, spacing: PrismFeedLayout.gridSpacing),
                    delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
                      final PrismWallpaper wall = walls[index];
                      final PrismFeedItem item = PrismFeedItem(id: wall.id, wallpaper: wall);
                      if (wall.boostedUntil != null) {
                        return WallpaperTile(
                          item: item,
                          index: index,
                          quickActions: true,
                          overlay: boostedTagFor(wall),
                        );
                      }
                      return FeedWallTile(item: item, index: index, crossAxisCount: 3, memCacheHeight: 700);
                    }, childCount: walls.length),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await shot.settle(frames: 6, frameMs: 50);
    _expectTagsClear();
  }

  /// With the real fonts, no Depth tag may touch the heart or the premium star of its tile.
  void _expectTagsClear() {
    final List<Rect> marks = <Rect>[
      for (final Element e in find.byIcon(Icons.favorite_rounded).evaluate())
        tester.getRect(find.byElementPredicate((x) => x == e)),
      for (final Element e in find.byType(PremiumStarBadge).evaluate())
        tester.getRect(find.byElementPredicate((x) => x == e)),
    ];
    final List<Rect> tags = <Rect>[
      for (final Element e in find.byType(DepthTag).evaluate()) tester.getRect(find.byElementPredicate((x) => x == e)),
    ];
    expect(tags, hasLength(4));
    for (final Rect tag in tags) {
      for (final Rect mark in marks) {
        expect(tag.inflate(4).overlaps(mark), isFalse, reason: 'Depth tag $tag touches $mark');
      }
    }
  }

  Future<void> pumpDetail(WallDepthTier tier) async {
    final PrismWallpaper wall = _wall(7, tier);
    final FeedItemEntity entity = PrismFeedItem(id: wall.id, wallpaper: wall);
    final _MockDetailBloc bloc = _MockDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(
        entity: entity,
        paletteLoading: false,
        views: '1.2k',
        colors: const <Color>[Color(0xFF2B3A55), Color(0xFFE0A458), Color(0xFF8FA6C1), Color(0xFF1C1F26)],
      ),
    );
    await mount(
      BlocProvider<WallpaperDetailBloc>.value(
        value: bloc,
        child: WallpaperDetailScreen(entity: entity),
      ),
    );
    await shot.settle(frameMs: 50);
  }

  Future<void> openPanel() async {
    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await shot.settle(frames: 6, frameMs: 120);
  }

  Future<void> openGuide(WallDepthTier tier) async {
    await pumpDetail(tier);
    IosWallpaperGuideSession.shown = false;
    unawaited(showIosSetWallpaperGuide(tester.element(find.byType(WallpaperDetailScreen)), depthTier: tier));
    await shot.settle(frames: 6, frameMs: 120);
  }

  Future<void> showSavedToast(WallDepthTier tier) async {
    await pumpDetail(tier);
    IosWallpaperGuideSession.shown = true;
    final OverlayState overlay = tester.state<NavigatorState>(find.byType(Navigator)).overlay!;
    showPrismToast(overlay, savedWallpaperMessage(depthTier: tier), kind: PrismToastKind.success);
    await shot.settle(frames: 2, frameMs: 200);
  }

  Future<void> save(String name) async {
    final RenderRepaintBoundary render = shot.boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final File file = File('$_outDir/$name.png');
    await tester.runAsync(() async {
      final ui.Image image = await render.toImage(pixelRatio: 3);
      final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Toasts and the default cache manager leave timers, and a test may not end with one pending.
    await tester.pump(const Duration(seconds: 11));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    QaPhotoCache.uninstall();
    PrismFullImageCache.testOverride = null;
    AnalyticsRuntime.reset();
    IosWallpaperGuideSession.shown = false;
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  }
}

void main() {
  final List<String> results = <String>[];

  setUpAll(() async {
    registerFallbackValue(ProfileRoute());
    if (homeRender) await loadAppFonts();
  });

  tearDownAll(() {
    if (!homeRender) return;
    // ignore: avoid_print
    print('\nQA_RENDER results\n${results.join('\n')}');
  });

  void scene(String name, ThemeData theme, Future<void> Function(_Depth depth) body) {
    testWidgets(name, skip: !homeRender, (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final _Depth depth = _Depth(tester, theme);
      try {
        await depth.setUp();
        await body(depth);
        await depth.save(name);
        final Object? exception = tester.takeException();
        results.add(exception == null ? 'OK    $name' : 'WARN  $name: $exception');
      } finally {
        await depth.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  scene('01-grid-dark', kDarkTheme, (_Depth d) => d.pumpGrid());
  scene('02-grid-light', kLightTheme, (_Depth d) => d.pumpGrid());
  scene('03-detail-auto-dark', kDarkTheme, (_Depth d) async {
    await d.pumpDetail(WallDepthTier.auto);
    await d.openPanel();
  });
  scene('04-detail-menu-dark', kDarkTheme, (_Depth d) async {
    await d.pumpDetail(WallDepthTier.menu);
    await d.openPanel();
  });
  scene('05-detail-menu-light', kLightTheme, (_Depth d) async {
    await d.pumpDetail(WallDepthTier.menu);
    await d.openPanel();
  });
  scene('06-guide-auto-dark', kDarkTheme, (_Depth d) => d.openGuide(WallDepthTier.auto));
  scene('07-guide-menu-dark', kDarkTheme, (_Depth d) => d.openGuide(WallDepthTier.menu));
  scene('08-guide-auto-light', kLightTheme, (_Depth d) => d.openGuide(WallDepthTier.auto));
  scene('09-saved-toast-menu-dark', kDarkTheme, (_Depth d) => d.showSavedToast(WallDepthTier.menu));
}
