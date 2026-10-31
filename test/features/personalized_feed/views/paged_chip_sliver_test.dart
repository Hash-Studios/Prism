import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/favourite_test_scope.dart';

class _MockFavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _FailingAiSettingStore extends InMemoryLocalStore {
  bool failAiWrites = false;

  @override
  Future<void> set(String key, Object? value) async {
    if (failAiWrites && key == PersistenceKeys.settings(AiContentFilter.settingKey)) throw StateError('disk full');
    await super.set(key, value);
  }
}

class _MockPagedFeedBloc extends MockBloc<PagedFeedEvent, PagedFeedState> implements PagedFeedBloc {}

FeedItemEntity _aiItem(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
    isAiGenerated: true,
  ),
);

FeedItemEntity _item(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  ),
);

void main() {
  setUpFavouriteCounts();
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpSliver(WidgetTester tester, PagedFeedState state, {bool showAi = true}) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final paged = _MockPagedFeedBloc();
    when(() => paged.state).thenReturn(state);
    final favourites = _MockFavouriteBloc();
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
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
                  showAi: showAi,
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

  testWidgets('an all-AI page with AI hidden offers Show AI walls, which turns the setting on', (tester) async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    await AiContentFilter.setShowsAi(settings, false);
    await pumpSliver(
      tester,
      PagedFeedState.initial().copyWith(
        status: LoadStatus.success,
        items: <FeedItemEntity>[_aiItem('a'), _aiItem('b')],
        hasMore: false,
      ),
      showAi: false,
    );

    expect(find.text('No human-made walls here yet'), findsOneWidget);
    expect(find.text('Empty'), findsNothing);
    await tester.tap(find.text('Show AI walls'));
    await tester.pump();

    expect(AiContentFilter.showsAi(settings), isTrue);
  });

  testWidgets('Show AI walls reports a failed save instead of failing silently', (tester) async {
    final List<String> toasts = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      ),
    );
    final _FailingAiSettingStore store = _FailingAiSettingStore();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(store);
    await AiContentFilter.setShowsAi(settings, false);
    store.failAiWrites = true;
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    await pumpSliver(
      tester,
      PagedFeedState.initial().copyWith(
        status: LoadStatus.success,
        items: <FeedItemEntity>[_aiItem('a')],
        hasMore: false,
      ),
      showAi: false,
    );

    await tester.tap(find.text('Show AI walls'));
    await tester.pump();

    expect(toasts, <String>['Could not save feed settings. Try again.']);
    await tester.pump(const Duration(seconds: 1));
  });
}
