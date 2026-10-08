import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_local_store.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

FeedItemEntity _prism({List<String> collections = const <String>[], int? width, int? height}) => FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'prism-1',
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/full.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
      authorName: 'Akshay',
      width: width,
      height: height,
    ),
    collections: collections,
    tags: const <String>['space', 'stars'],
  ),
);

void main() {
  setUp(() {
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() => getIt.reset());

  Future<void> pumpDetail(WidgetTester tester, WallpaperDetailLoaded state) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: state.entity),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Android shows a labelled Set action and icon actions with tooltips, on the details panel', (
    tester,
  ) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.text('Set'), findsOneWidget);
    expect(find.byType(SetWallpaperButton), findsOneWidget);
    expect(find.byType(DownloadButton), findsOneWidget);
    expect(find.byType(FavouriteWallpaperButton), findsOneWidget);
    expect(find.byType(ShareButton), findsOneWidget);
    expect(find.byType(EditButton), findsOneWidget);
    for (final String tooltip in <String>['Set as wallpaper', 'Download', 'Favourite', 'Share', 'Edit']) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
    expect(tester.getRect(find.byType(SetWallpaperButton)).bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the action bar stays at the bottom when the details panel opens', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    final Rect before = tester.getRect(find.byType(SetWallpaperButton));
    final double chipTopBefore = tester.getRect(find.widgetWithText(ActionChip, 'space')).top;

    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.getRect(find.byType(SetWallpaperButton)), before);
    expect(tester.getRect(find.widgetWithText(ActionChip, 'space')).top, lessThan(chipTopBefore));
    expect(tester.getRect(find.widgetWithText(ActionChip, 'space')).bottom, lessThanOrEqualTo(before.top));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('collapsed panel content is faded out and returns when the panel opens', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.bySemanticsLabel('Original wallpaper colors'), findsNothing);
    final Opacity chipFade = tester.widget<Opacity>(
      find.ancestor(of: find.widgetWithText(ActionChip, 'space'), matching: find.byType(Opacity)).first,
    );
    expect(chipFade.opacity, 0);
    expect(tester.getSemantics(find.bySemanticsLabel('Expand wallpaper details')).rect.height, lessThan(100));

    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('Original wallpaper colors'), findsOneWidget);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS shows Save as the primary action and no Set action', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(SetWallpaperButton), findsNothing);
    expect(find.byType(DownloadButton), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a wall in a premium collection is a premium download', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(entity: _prism(collections: <String>['space']), paletteLoading: false),
    );
    final DownloadButton premium = tester.widget<DownloadButton>(find.byType(DownloadButton));

    expect(premium.isPremiumContent, isTrue);
    expect(premium.contentId, 'prism-1');
  });

  testWidgets('a wall in a free collection is a normal download', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(entity: _prism(collections: <String>['Nature']), paletteLoading: false),
    );

    expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).isPremiumContent, isFalse);
  });

  testWidgets('choosing an accent does not tint the wallpaper', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Colors.teal],
        accent: Colors.teal,
        colorChanged: true,
      ),
    );

    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('a wall smaller than the screen shows the low resolution note', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(width: 100, height: 100), paletteLoading: false));

    expect(find.text('Low resolution for your screen'), findsOneWidget);
  });

  testWidgets('a large wall shows no low resolution note', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(width: 9000, height: 9000), paletteLoading: false));

    expect(find.text('Low resolution for your screen'), findsNothing);
  });

  testWidgets('the tags show as chips', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.widgetWithText(ActionChip, 'space'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'stars'), findsOneWidget);
  });

  testWidgets('the similar strip stays hidden when it cannot load', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('More like this'), findsNothing);
  });
}
