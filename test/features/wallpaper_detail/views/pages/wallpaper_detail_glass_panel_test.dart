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
import 'package:Prism/theme/app_tokens.dart';
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
        builder: favouriteTestBuilder,
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
    // A 9:16 wall fills a rounded card under the status bar, 4 points in from each side, up to 66% of the screen.
    expect(image, const Rect.fromLTRB(4, 47, 386, 47 + 844 * 0.66));
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

  testWidgets('the card is rounded, and Back and the clock stay in its top corners while the feed scrolls', (
    tester,
  ) async {
    await pump(tester);
    final card = tester.getRect(find.byType(ShakeOnce));
    final clip = tester.widget<ClipRRect>(
      find.descendant(of: find.byType(ShakeOnce), matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, const BorderRadius.all(Radius.circular(20)));
    final back = tester.getRect(find.byTooltip('Back'));
    final clock = tester.getRect(find.byTooltip('Preview on your screen'));
    expect(back, Rect.fromLTWH(card.left + 4, card.top + 4, 44, 44));
    expect(clock, Rect.fromLTWH(card.right - 4 - 44, card.top + 4, 44, 44));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byTooltip('Back')), back);
    expect(tester.getRect(find.byTooltip('Preview on your screen')), clock);
  });

  testWidgets('Back and the clock sit on the theme scrim with the light on-scrim ink', (tester) async {
    const Color scrim = Color(0xFF102030);
    await pump(
      tester,
      theme: ThemeData(colorScheme: const ColorScheme.light(scrim: scrim)),
    );
    for (final String tooltip in <String>['Back', 'Preview on your screen']) {
      final IconButton button = tester.widget<IconButton>(
        find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)),
      );
      expect(button.style!.backgroundColor!.resolve(<WidgetState>{}), scrim.withValues(alpha: 0.55), reason: tooltip);
      expect(button.color, PrismColors.onPrimary, reason: tooltip);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('$brightness status icons follow the page, then the card under them, then the feed', (tester) async {
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
      final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
      // At rest the card starts under the status bar, so the icons sit on the page.
      // The rows and the feed pass under the icons on a fade of the page colour; the card and the page do not.
      double fade() => tester.widget<AnimatedOpacity>(find.byKey(const ValueKey<String>('detail-status-fade'))).opacity;
      final pageStyle = overlay();
      expect(pageStyle.value.statusBarIconBrightness, lightFeed ? Brightness.dark : Brightness.light);
      expect(fade(), 0);
      const iconLine = 47 / 2;
      final cardHeight = tester.getRect(find.byType(ShakeOnce)).height;

      scroll.jumpTo(iconLine - 1);
      await tester.pump();
      expect(overlay(), same(pageStyle), reason: 'the card has not reached the status bar icons');
      scroll.jumpTo(iconLine + 1);
      await tester.pump();
      final imageStyle = overlay();
      expect(imageStyle.value.statusBarIconBrightness, lightFeed ? Brightness.light : Brightness.dark);
      expect(fade(), 0);
      scroll.jumpTo(cardHeight + iconLine - 1);
      await tester.pump();
      expect(overlay(), same(imageStyle), reason: 'scrolling within the card must not rebuild the detail shell');
      scroll.jumpTo(cardHeight + iconLine + 1);
      await tester.pump();
      final feedStyle = overlay();
      expect(feedStyle.value.statusBarIconBrightness, pageStyle.value.statusBarIconBrightness);
      expect(fade(), 1);
      scroll.jumpTo(cardHeight + 300);
      await tester.pump();
      expect(overlay(), same(feedStyle), reason: 'scrolling within the feed must not rebuild the detail shell');
      scroll.jumpTo(0);
      await tester.pump();
      expect(overlay().value.statusBarIconBrightness, pageStyle.value.statusBarIconBrightness);
      expect(fade(), 0);
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
