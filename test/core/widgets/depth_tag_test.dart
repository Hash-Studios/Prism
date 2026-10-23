import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/depth_tag.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/trending/views/widgets/boosted_tag.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';
import '../../support/favourite_test_scope.dart';

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

PrismWallpaper _wall(WallDepthTier? tier, {DateTime? boostedUntil}) => PrismWallpaper(
  core: const WallpaperCore(
    id: 'wall-1',
    source: WallpaperSource.prism,
    fullUrl: 'https://example.test/wall-1.jpg',
    thumbnailUrl: '',
    authorName: 'Ana',
  ),
  depthTier: tier,
  boostedUntil: boostedUntil,
);

void main() {
  setUpFavouriteCounts();
  late FavoritesLocalDataSource favourites;
  late _MockFavouriteWallsBloc bloc;

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u'
      ..loggedIn = true;
    favourites = FavoritesLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<FavoritesLocalDataSource>(favourites);
    bloc = _MockFavouriteWallsBloc();
    whenListen(
      bloc,
      const Stream<FavouriteWallsState>.empty(),
      initialState: FavouriteWallsState.initial().copyWith(status: LoadStatus.success, userId: 'u'),
    );
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  void onPlatform(String name, TargetPlatform platform, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Future<void> pumpTile(WidgetTester tester, PrismWallpaper wall, {Widget? overlay}) {
    return tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 116,
                height: 232,
                child: WallpaperTile(
                  item: PrismFeedItem(id: wall.id, wallpaper: wall),
                  index: 0,
                  quickActions: true,
                  overlay: overlay,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('depthTagFor', () {
    onPlatform('gives a tag for auto and menu walls on iOS, and none for the rest', TargetPlatform.iOS, (_) async {
      expect(depthTagFor(WallDepthTier.auto), isNotNull);
      expect(depthTagFor(WallDepthTier.menu), isNotNull);
      expect(depthTagFor(WallDepthTier.none), isNull);
      expect(depthTagFor(null), isNull);
    });

    onPlatform('gives no tag on Android, where the Depth Effect does not exist', TargetPlatform.android, (_) async {
      expect(depthTagFor(WallDepthTier.auto), isNull);
      expect(depthTagFor(WallDepthTier.menu), isNull);
    });

    test('only Prism walls carry a tier', () {
      final PrismWallpaper wall = _wall(WallDepthTier.menu);
      expect(depthTierOf(PrismFeedItem(id: wall.id, wallpaper: wall)), WallDepthTier.menu);
      expect(
        depthTierOf(
          const WallhavenFeedItem(
            id: 'w',
            wallpaper: WallhavenWallpaper(
              core: WallpaperCore(id: 'w', source: WallpaperSource.wallhaven, fullUrl: '', thumbnailUrl: ''),
            ),
          ),
        ),
        isNull,
      );
    });
  });

  group('on a feed tile', () {
    for (final WallDepthTier tier in <WallDepthTier>[WallDepthTier.auto, WallDepthTier.menu]) {
      onPlatform('a ${tier.name} wall shows the Depth tag with a label on iOS', TargetPlatform.iOS, (tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        await pumpTile(tester, _wall(tier));

        expect(find.byType(DepthTag), findsOneWidget);
        expect(find.text('Depth'), findsOneWidget);
        // The tile merges its badges into one node, so the label is part of what the tile reads out.
        expect(
          tester.getSemantics(find.byType(DepthTag)).label,
          contains(AppLocalizationsEn().coreDepthEffectBadgeSemantic),
        );
        semantics.dispose();
      });
    }

    for (final WallDepthTier? tier in <WallDepthTier?>[WallDepthTier.none, null]) {
      onPlatform('a wall with tier ${tier?.name} shows no Depth tag on iOS', TargetPlatform.iOS, (tester) async {
        await pumpTile(tester, _wall(tier));

        expect(find.byType(DepthTag), findsNothing);
      });
    }

    onPlatform('an auto wall shows no Depth tag on Android', TargetPlatform.android, (tester) async {
      await pumpTile(tester, _wall(WallDepthTier.auto));

      expect(find.byType(DepthTag), findsNothing);
    });

    // The test font draws every glyph as a wide square, so the real widths are checked in depth_render_test.dart.
    onPlatform(
      'the tag stays on the image, above the favourite footer and clear of the Boosted tag',
      TargetPlatform.iOS,
      (tester) async {
        await favourites.setWallFavourite('u', 'wall-1', true);
        final PrismWallpaper wall = _wall(
          WallDepthTier.auto,
          boostedUntil: DateTime.now().add(const Duration(hours: 1)),
        );
        whenListen(
          bloc,
          const Stream<FavouriteWallsState>.empty(),
          initialState: FavouriteWallsState.initial().copyWith(
            status: LoadStatus.success,
            userId: 'u',
            items: [FavouriteWallEntity.fromFeedItem(PrismFeedItem(id: wall.id, wallpaper: wall))],
          ),
        );
        await pumpTile(tester, wall, overlay: boostedTagFor(wall));

        final Rect tile = tester.getRect(find.byType(WallpaperTile));
        final Rect depth = tester.getRect(find.byType(DepthTag));
        final Rect boosted = tester.getRect(find.byType(BoostedTag));
        final Rect heart = tester.getRect(find.byIcon(Icons.favorite_rounded));

        expect(depth.left - tile.left, 6);
        expect(tile.bottom - depth.bottom, 50);
        expect(heart.top, greaterThan(depth.bottom));
        expect(heart.left, greaterThanOrEqualTo(tile.left));
        expect(heart.bottom, lessThanOrEqualTo(tile.bottom));
        expect(depth.height, boosted.height);
        expect(depth.overlaps(boosted), isFalse);
      },
    );
  });
}
