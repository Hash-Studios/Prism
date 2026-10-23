import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _DetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

FeedItemEntity _item(String id) => PexelsFeedItem(
  id: id,
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.pexels,
      fullUrl: '',
      thumbnailUrl: '',
      width: 1080,
      height: 1920,
    ),
  ),
);

WallpaperDetailLoaded _loaded(String id) => WallpaperDetailLoaded(
  entity: _item(id),
  paletteLoading: false,
  recommendations: RecommendationState(
    items: List.generate(30, (index) => _item('$index')),
    kind: RecommendationKind.discovery,
    status: RecommendationStatus.exhausted,
  ),
);

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture assets;
  setUp(() async {
    assets = await OfflineAssetFixture.create();
    assets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
  });
  tearDown(() async {
    await assets.dispose();
    await getIt.reset();
  });

  Future<_DetailBloc> pump(
    WidgetTester tester, {
    GlobalKey<NavigatorState>? navigatorKey,
    WallpaperDetailLoaded? state,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    final bloc = _DetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state ?? _loaded('parent'));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: _item('parent')),
        ),
      ),
    );
    await tester.pump();
    return bloc;
  }

  testWidgets('image, actions, summary and a hint of lazy recommendations share one scroll', (tester) async {
    await pump(tester);
    final image = tester.getRect(find.byType(ShakeOnce));
    final actions = tester.getRect(find.byType(WallpaperActionBar));
    expect(image, const Rect.fromLTWH(0, 0, 390, 523.28));
    expect(actions.top, image.bottom);
    expect(tester.getRect(find.byType(PrismWallTile).first).top, lessThan(844));
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(PrismWallTile).evaluate().length, lessThan(30));
    expect(find.bySemanticsLabel('Original wallpaper colors'), findsOneWidget);
    final quick = tester.widgetList<WallpaperQuickActionRegion>(find.byType(WallpaperQuickActionRegion));
    expect(quick.first.onResetOriginal, isNotNull);
    expect(quick.skip(1).every((region) => region.onResetOriginal == null), isTrue);
  });

  testWidgets('Back stays in the safe area after scrolling deeply into discovery', (tester) async {
    await pump(tester);
    final before = tester.getRect(find.byTooltip('Back'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byTooltip('Back')), before);
    expect(before.top, greaterThanOrEqualTo(47));
    expect(before.bottom, lessThan(47 + kMinInteractiveDimension + 24));
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    expect(scroll.offset, greaterThan(1000));
    expect(find.byType(PrismWallTile).evaluate().length, lessThan(30));
  });

  for (final brightness in Brightness.values) {
    testWidgets('$brightness status icons follow the image then feed and restore on scroll back', (tester) async {
      final lightFeed = brightness == Brightness.light;
      await pump(
        tester,
        state: _loaded('parent').copyWith(accent: lightFeed ? Colors.black : Colors.white),
        theme: ThemeData(brightness: brightness, scaffoldBackgroundColor: lightFeed ? Colors.white : Colors.black),
      );
      final region = find
          .descendant(
            of: find.byType(WallpaperDetailScreen),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first;
      AnnotatedRegion<SystemUiOverlayStyle> overlay() => tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(region);
      final imageStyle = overlay();
      final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
      final boundary = tester.getRect(find.byType(ShakeOnce)).height - 47;
      expect(imageStyle.value.statusBarIconBrightness, lightFeed ? Brightness.light : Brightness.dark);

      scroll.jumpTo(boundary - 1);
      await tester.pump();
      expect(overlay(), same(imageStyle), reason: 'scrolling within the image must not rebuild the detail shell');
      scroll.jumpTo(boundary + 1);
      await tester.pump();
      final feedStyle = overlay();
      expect(feedStyle.value.statusBarIconBrightness, lightFeed ? Brightness.dark : Brightness.light);
      scroll.jumpTo(boundary + 300);
      await tester.pump();
      expect(overlay(), same(feedStyle), reason: 'scrolling within the feed must not rebuild the detail shell');
      scroll.jumpTo(0);
      await tester.pump();
      expect(overlay().value.statusBarIconBrightness, imageStyle.value.statusBarIconBrightness);
    });
  }

  testWidgets('a nested detail pop restores the exact feed, scroll offset and hero tags', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final parent = await pump(tester, navigatorKey: nav);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1300));
    await tester.pumpAndSettle();
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    final offset = scroll.offset;
    final tags = tester.widgetList<PrismWallTile>(find.byType(PrismWallTile)).map((tile) => tile.heroTag).toList();
    final child = _DetailBloc();
    whenListen(child, const Stream<WallpaperDetailState>.empty(), initialState: _loaded('child'));
    unawaited(
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider<WallpaperDetailBloc>.value(
            value: child,
            child: WallpaperDetailScreen(entity: _item('child')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect((child.state as WallpaperDetailLoaded).entity.id, 'child');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!.offset, offset);
    expect(tester.widgetList<PrismWallTile>(find.byType(PrismWallTile)).map((tile) => tile.heroTag), tags);
    expect((parent.state as WallpaperDetailLoaded).recommendations.items.map((item) => item.id), [
      for (var index = 0; index < 30; index++) '$index',
    ]);
    expect((parent.state as WallpaperDetailLoaded).entity.id, 'parent');
  });
}
