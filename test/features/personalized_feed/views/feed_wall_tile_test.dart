import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';

class _MockFavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

const FeedItemEntity _item = FeedItemEntity.prism(
  id: 'w1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: 'w1', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
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

  Future<void> pumpTile(WidgetTester tester, Widget tile) async {
    final favourites = _MockFavouriteBloc();
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: BlocProvider<FavouriteWallsBloc>.value(
            value: favourites,
            child: SizedBox(width: 100, height: 200, child: tile),
          ),
        ),
      ),
    );
  }

  BorderRadius tileRadius(WidgetTester tester) => tester.widget<PrismWallTile>(find.byType(PrismWallTile)).borderRadius;

  testWidgets('a home grid tile has rounded corners', (tester) async {
    await pumpTile(tester, const FeedWallTile(item: _item, index: 0, crossAxisCount: 3, memCacheHeight: 400));

    expect(tileRadius(tester), BorderRadius.circular(12));
  });
}
