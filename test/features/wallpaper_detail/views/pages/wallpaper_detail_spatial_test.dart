import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/spatial_scene_row.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

FeedItemEntity _prism(WallSpatialTier? tier) => FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: const WallpaperCore(
      id: 'prism-1',
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/full.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
      authorName: 'Akshay',
    ),
    tags: const <String>['space', 'stars'],
    spatial: tier == null ? null : WallSpatial(tier: tier),
  ),
);

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture offlineAssets;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() async {
    offlineAssets = await OfflineAssetFixture.create();
    offlineAssets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (call) async => true,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    await offlineAssets.dispose();
    await getIt.reset();
  });

  Future<void> pumpDetail(WidgetTester tester, WallSpatialTier? tier, {double height = 844}) async {
    tester.view.physicalSize = Size(390 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final WallpaperDetailLoaded state = WallpaperDetailLoaded(
      recommendations: const RecommendationState.exhausted(),
      entity: _prism(tier),
      paletteLoading: false,
    );
    final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state.copyWith(panelCollapsed: false));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        themeAnimationDuration: Duration.zero,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: state.entity),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  void onPlatform(String name, TargetPlatform platform, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  final AppLocalizationsEn l10n = AppLocalizationsEn();

  for (final (WallSpatialTier tier, String subtitle) in <(WallSpatialTier, String)>[
    (WallSpatialTier.great, l10n.wallpaperSpatialGreatSubtitle),
    (WallSpatialTier.ok, l10n.wallpaperSpatialOkSubtitle),
  ]) {
    onPlatform('a ${tier.name} wall shows the Spatial Scene row and passes its tier to Save', TargetPlatform.iOS, (
      tester,
    ) async {
      await pumpDetail(tester, tier);

      expect(find.byType(SpatialSceneRow), findsOneWidget);
      expect(find.text(l10n.wallpaperSpatialScene), findsOneWidget);
      expect(find.text(subtitle), findsOneWidget);
      expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).spatialTier, tier);
    });
  }

  onPlatform('a none wall has no Spatial Scene row', TargetPlatform.iOS, (tester) async {
    await pumpDetail(tester, WallSpatialTier.none);

    expect(find.byType(SpatialSceneRow), findsNothing);
    expect(find.text(l10n.wallpaperSpatialScene), findsNothing);
  });

  onPlatform('a wall that was not checked has no Spatial Scene row', TargetPlatform.iOS, (tester) async {
    await pumpDetail(tester, null);

    expect(find.byType(SpatialSceneRow), findsNothing);
  });

  onPlatform('Android has no Spatial Scene row, even for a great wall', TargetPlatform.android, (tester) async {
    await pumpDetail(tester, WallSpatialTier.great);

    expect(find.byType(SpatialSceneRow), findsNothing);
  });

  onPlatform('tapping the Spatial Scene row opens the guide sheet', TargetPlatform.iOS, (tester) async {
    await pumpDetail(tester, WallSpatialTier.great, height: 1600);

    await tester.tap(find.byType(SpatialSceneRow));
    await tester.pumpAndSettle();

    expect(find.byType(SpatialSceneGuideSheet), findsOneWidget);
    expect(find.text(l10n.wallpaperSpatialGuideTitle), findsOneWidget);
  });
}
