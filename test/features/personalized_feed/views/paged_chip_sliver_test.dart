import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/paged_chip_sliver.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';

class _MockFavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _MockPagedFeedBloc extends MockBloc<PagedFeedEvent, PagedFeedState> implements PagedFeedBloc {}

FeedItemEntity _item(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  ),
);

void main() {
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpSliver(WidgetTester tester, PagedFeedState state) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final paged = _MockPagedFeedBloc();
    when(() => paged.state).thenReturn(state);
    final favourites = _MockFavouriteBloc();
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: BlocProvider<FavouriteWallsBloc>.value(
            value: favourites,
            child: CustomScrollView(
              slivers: <Widget>[
                PagedChipSliver(
                  bloc: paged,
                  failureTitle: 'Failed',
                  emptyTitle: 'Empty',
                  crossAxisCount: 3,
                  tileMemCacheHeight: 400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the grid has a 4 px side margin, 4 px gaps both ways and rounded tiles', (tester) async {
    await pumpSliver(
      tester,
      PagedFeedState.initial().copyWith(
        status: LoadStatus.success,
        items: <FeedItemEntity>[
          for (final String id in <String>['a', 'b', 'c', 'd', 'e', 'f']) _item(id),
        ],
      ),
    );

    final List<Rect> tiles = [for (int i = 0; i < 6; i++) tester.getRect(find.byType(FeedWallTile).at(i))];
    expect(tiles[0].left, 4);
    expect(tiles[2].right, closeTo(596, 0.01));
    expect(tiles[1].left - tiles[0].right, closeTo(4, 0.01));
    expect(tiles[2].left - tiles[1].right, closeTo(4, 0.01));
    expect(tiles[3].top - tiles[0].bottom, closeTo(4, 0.01));
    for (final Element tile in find.byType(PrismWallTile).evaluate()) {
      expect((tile.widget as PrismWallTile).borderRadius, BorderRadius.circular(12));
    }
  });

  testWidgets('the first load shows the home skeleton while the tab has no walls yet', (tester) async {
    await pumpSliver(tester, PagedFeedState.initial().copyWith(status: LoadStatus.loading));

    expect(tester.widget<LoadingCards>(find.byType(LoadingCards)).useFeedLayout, isTrue);
    expect(tester.getTopLeft(find.byType(PulseFill).first).dx, 4);
  });
}
