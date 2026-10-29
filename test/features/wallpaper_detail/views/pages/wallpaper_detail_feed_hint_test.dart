import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

FeedItemEntity _item(String id, {required int width, required int height}) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      width: width,
      height: height,
    ),
  ),
);

void main() {
  setUpFavouriteCounts();
  setUpAll(() => registerFallbackValue(const OnPanelOpened()));
  late OfflineAssetFixture offlineAssets;
  final List<FeedItemEntity> blocWalls = <FeedItemEntity>[];

  setUp(() async {
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = _MockDetailBloc();
      whenListen(
        bloc,
        const Stream<WallpaperDetailState>.empty(),
        initialState: WallpaperDetailLoaded(
          entity: blocWalls.removeAt(0),
          paletteLoading: false,
          recommendations: const RecommendationState.exhausted(),
        ),
      );
      return bloc;
    });
  });

  tearDown(() async {
    await offlineAssets.dispose();
    await getIt.reset();
  });

  testWidgets('feed entry hint applies only to its entry and survives a round trip', (tester) async {
    const FeedItemEntity entry = FeedItemEntity.prism(
      id: 'entry',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'entry',
          source: WallpaperSource.prism,
          fullUrl: 'https://example.com/entry.jpg',
          thumbnailUrl: 'https://example.com/entry-thumb.jpg',
          width: 1600,
          height: 900,
        ),
      ),
    );
    final FeedItemEntity neighbor = _item('neighbor', width: 1, height: 1);
    blocWalls.addAll(<FeedItemEntity>[entry, neighbor, entry]);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final WallpaperFeed feed = WallpaperFeed(
              grid: context,
              tiles: <WallpaperFeedTile>[
                (item: entry, index: 0, heroTag: 'tile-entry'),
                (item: neighbor, index: 1, heroTag: 'tile-neighbor'),
              ],
            );
            return WallpaperDetailScreen(
              entity: entry,
              feed: feed,
              heroTag: 'tile-entry',
              aspectRatio: 3 / 2,
            ).wrappedRoute(context);
          },
        ),
      ),
    );
    await tester.pump();

    double ratio() {
      final Size size = tester.getSize(find.byType(WallpaperDetailHero));
      return size.width / size.height;
    }

    expect(ratio(), closeTo(3 / 2, 0.01));
    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(ratio(), closeTo(1, 0.01));

    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(ratio(), closeTo(3 / 2, 0.01));
    await tester.pumpWidget(const SizedBox());
  });
}
