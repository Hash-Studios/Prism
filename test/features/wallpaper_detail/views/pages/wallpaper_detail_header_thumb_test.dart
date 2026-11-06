import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/gesture_hint.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _DetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

const String _thumb = 'https://images.pexels.com/photos/1/thumb.jpg';

FeedItemEntity _item(String id, {String thumbnail = ''}) => PexelsFeedItem(
  id: id,
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.pexels,
      fullUrl: '',
      thumbnailUrl: thumbnail,
      width: 1080,
      height: 1920,
    ),
  ),
);

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture assets;
  setUp(() async {
    assets = await OfflineAssetFixture.create();
    assets.install();
    GestureHints.resetForTest();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
  });
  tearDown(() async {
    GestureHints.resetForTest();
    await assets.dispose();
    await getIt.reset();
  });

  Future<ScrollController> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    final bloc = _DetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(
        entity: _item('parent', thumbnail: _thumb),
        paletteLoading: false,
        colors: const <Color>[Colors.red, Colors.blue],
        recommendations: RecommendationState(
          items: List.generate(30, (index) => _item('$index')),
          kind: RecommendationKind.related,
          status: RecommendationStatus.exhausted,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: _item('parent', thumbnail: _thumb)),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
  }

  double swatches(WidgetTester tester) =>
      tester.widget<Opacity>(find.byKey(const ValueKey<String>('detail-swatches'))).opacity;

  testWidgets('the header thumbnail sits a fixed gap after Back on every frame as the header takes over', (
    tester,
  ) async {
    final ScrollController scroll = await pump(tester);
    final Finder thumb = find.byKey(const ValueKey<String>('detail-header-thumb'));
    final Finder backs = find.byWidgetPredicate(
      (widget) =>
          widget.key == const ValueKey<String>('detail-card-back') ||
          widget.key == const ValueKey<String>('detail-header-back'),
    );

    scroll.jumpTo(scroll.position.maxScrollExtent / 2);
    await tester.pump();
    for (int frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final Rect picture = tester.getRect(thumb);
      for (final Element back in backs.evaluate()) {
        final Rect box = tester.getRect(find.byWidget(back.widget));
        expect(picture.left, greaterThanOrEqualTo(box.right + 4 - 0.01), reason: 'frame $frame: thumb on Back');
      }
    }
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(thumb).opacity, 1);
    expect(tester.getRect(thumb).left - tester.getRect(backs).right, moreOrLessEquals(4));
  });

  testWidgets('the swatches fade out with the scroll and are gone before the header thumbnail arrives', (tester) async {
    final ScrollController scroll = await pump(tester);
    final Finder thumb = find.byKey(const ValueKey<String>('detail-header-thumb'));
    expect(swatches(tester), 1);

    // Step towards the header one point at a time: the swatches are gone while the thumbnail is still hidden.
    double offset = 0;
    while (tester.widget<AnimatedOpacity>(thumb).opacity == 0) {
      offset += 1;
      scroll.jumpTo(offset);
      await tester.pump();
      if (tester.widget<AnimatedOpacity>(thumb).opacity == 0) continue;
      expect(swatches(tester), 0, reason: 'the header took over at $offset with the swatches still showing');
    }
    expect(offset, greaterThan(100));

    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(swatches(tester), 1);
  });
}
