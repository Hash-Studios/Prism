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
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

Future<void> _pumpOfflinePreview(WidgetTester tester) async {
  final Stopwatch timeout = Stopwatch()..start();
  while (find.byType(CachedNetworkImage).evaluate().isEmpty && timeout.elapsed < const Duration(seconds: 2)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)).timeout(const Duration(seconds: 2)),
    );
    await tester.pump();
  }
}

FeedItemEntity _item(String id) => FeedItemEntity.prism(
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

Future<void> _pumpFeed(WidgetTester tester, {required List<FeedItemEntity> feed, required FeedItemEntity open}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => WallpaperDetailScreen(entity: open, feed: feed, heroTag: 'tile').wrappedRoute(context),
      ),
    ),
  );
  await _pumpOfflinePreview(tester);
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

  testWidgets('a swipe left on the card shows the next wall of the feed', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b, c]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);

    List<String?> urls() =>
        tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl).toList();
    expect(urls(), contains('https://example.com/b-thumb.jpg'));
    expect(find.byType(Hero), findsOneWidget);

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    expect(urls(), contains('https://example.com/c-thumb.jpg'));
    expect(urls().where((u) => u!.contains('b-thumb')), isEmpty);
    expect(find.byType(Hero), findsNothing);
    expect(blocWalls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swipe right shows the previous wall', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b, a]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(300, 0));
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
    expect(urls, contains('https://example.com/a-thumb.jpg'));
    expect(urls.where((u) => u.contains('b-thumb')), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the last wall does not move past the end', (tester) async {
    final a = _item('a');
    final b = _item('b');
    blocWalls.addAll([b]);
    await _pumpFeed(tester, feed: [a, b], open: b);

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
    expect(urls, contains('https://example.com/b-thumb.jpg'));
    expect(find.byType(Hero), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without a feed a swipe does nothing', (tester) async {
    final b = _item('b');
    blocWalls.addAll([b]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => WallpaperDetailScreen(entity: b, heroTag: 'tile').wrappedRoute(context),
        ),
      ),
    );
    await _pumpOfflinePreview(tester);

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
    expect(urls, contains('https://example.com/b-thumb.jpg'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the card offers next and previous actions to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);

    final Semantics card = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.customSemanticsActions != null);
    expect(card.properties.customSemanticsActions!.keys.map((a) => a.label), <String>[
      'Previous wallpaper',
      'Next wallpaper',
    ]);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
