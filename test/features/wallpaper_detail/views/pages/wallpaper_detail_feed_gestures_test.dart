import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

FeedItemEntity _prism(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
    ),
  ),
);

FeedItemEntity _wallhaven(String id) => FeedItemEntity.wallhaven(
  id: id,
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
    ),
  ),
);

WallpaperFeed _feedOf(BuildContext context, List<FeedItemEntity> items) => WallpaperFeed(
  grid: context,
  tiles: [for (final (i, item) in items.indexed) (item: item, index: i, heroTag: 'tile-$i')],
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<FeedItemEntity> feed,
  required FeedItemEntity open,
  bool reduceMotion = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: WallpaperDetailScreen(
            entity: open,
            feed: _feedOf(context, feed),
            heroTag: feed.contains(open) ? 'tile-${feed.indexOf(open)}' : 'tile',
          ).wrappedRoute(context),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture offlineAssets;
  final List<FeedItemEntity> blocWalls = <FeedItemEntity>[];

  setUp(() async {
    blocWalls.clear();
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = _MockDetailBloc();
      final FeedItemEntity item = blocWalls.removeAt(0);
      whenListen(
        bloc,
        const Stream<WallpaperDetailState>.empty(),
        initialState: WallpaperDetailLoaded(
          entity: item,
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

  testWidgets('vertical card drag scrolls details without changing the opened wallpaper', (tester) async {
    final FeedItemEntity a = _prism('a');
    final FeedItemEntity b = _prism('b');
    blocWalls.addAll(<FeedItemEntity>[a, b]);
    await _pumpScreen(tester, feed: <FeedItemEntity>[a, b], open: a, size: const Size(390, 480));
    final ScrollController scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(0, -280));
    await tester.pumpAndSettle();

    expect(scroll.offset, greaterThan(0));
    expect(tester.widget<WallpaperQuickActionRegion>(find.byType(WallpaperQuickActionRegion).first).item.id, 'a');
    expect(blocWalls, <FeedItemEntity>[b]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('long press opens quick-action preview without changing the wallpaper', (tester) async {
    final FeedItemEntity a = _prism('a');
    final FeedItemEntity b = _prism('b');
    blocWalls.addAll(<FeedItemEntity>[a, b]);
    await _pumpScreen(tester, feed: <FeedItemEntity>[a, b], open: a);
    final TestGesture hold = await tester.startGesture(tester.getCenter(find.byType(WallpaperQuickActionRegion).first));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('wallpaper-hold-scrim')), findsOneWidget);
    expect(find.bySemanticsLabel('Favourite'), findsAtLeastNWidgets(1));
    expect(find.bySemanticsLabel('Share'), findsAtLeastNWidgets(1));
    expect(tester.widget<WallpaperQuickActionRegion>(find.byType(WallpaperQuickActionRegion).first).item.id, 'a');

    await hold.up();
    await tester.pumpAndSettle();
    expect(tester.widget<WallpaperQuickActionRegion>(find.byType(WallpaperQuickActionRegion).first).item.id, 'a');
    expect(blocWalls, <FeedItemEntity>[b]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion shows the next wallpaper without a slide offset', (tester) async {
    final FeedItemEntity a = _prism('a');
    final FeedItemEntity b = _prism('b');
    blocWalls.addAll(<FeedItemEntity>[a, b]);
    await _pumpScreen(tester, feed: <FeedItemEntity>[a, b], open: a, reduceMotion: true);
    final Rect original = tester.getRect(find.byType(WallpaperQuickActionRegion).first);
    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0));
    await tester.pump();

    final Finder next = find.byWidgetPredicate(
      (widget) => widget is WallpaperQuickActionRegion && widget.item.id == 'b',
    );
    expect(next, findsOneWidget);
    expect(tester.getRect(next).left, closeTo(original.left, 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty and source-mismatched feeds keep the opened wall without feed actions', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final FeedItemEntity opened = _prism('same-id');
    for (final List<FeedItemEntity> feed in <List<FeedItemEntity>>[
      <FeedItemEntity>[],
      <FeedItemEntity>[_wallhaven('same-id'), _prism('next')],
    ]) {
      blocWalls.add(opened);
      await _pumpScreen(tester, feed: feed, open: opened);
      final WallpaperQuickActionRegion card = tester.widget<WallpaperQuickActionRegion>(
        find.byType(WallpaperQuickActionRegion).first,
      );
      expect(card.item.source, WallpaperSource.prism);
      expect(card.item.id, 'same-id');
      expect(
        tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((image) => image.imageUrl),
        contains('https://example.com/same-id-thumb.jpg'),
      );
      final Iterable<Semantics> feedCards = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((node) => node.properties.customSemanticsActions != null);
      expect(feedCards, isEmpty);
      await tester.pumpWidget(const SizedBox());
    }
    semantics.dispose();
  });
}
