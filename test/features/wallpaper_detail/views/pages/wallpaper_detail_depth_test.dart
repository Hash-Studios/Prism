import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
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
import 'package:Prism/features/wallpaper_detail/views/widgets/depth_effect_row.dart';
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

FeedItemEntity _prism(WallDepthTier? tier) => FeedItemEntity.prism(
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
    depthTier: tier,
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

  Future<void> pumpDetail(WidgetTester tester, WallDepthTier? tier) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
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

  for (final (WallDepthTier tier, String subtitle) in <(WallDepthTier, String)>[
    (WallDepthTier.auto, 'Your subject sits in front of the clock.'),
    (WallDepthTier.menu, 'In the Lock Screen editor, tap ••• then Depth Effect.'),
  ]) {
    onPlatform('a ${tier.name} wall shows the Depth Effect row and passes its tier to Save', TargetPlatform.iOS, (
      tester,
    ) async {
      await pumpDetail(tester, tier);

      expect(find.byType(DepthEffectRow), findsOneWidget);
      expect(find.text('Depth Effect'), findsOneWidget);
      expect(find.text(subtitle), findsOneWidget);
      expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).depthTier, tier);
    });
  }

  for (final WallDepthTier? tier in <WallDepthTier?>[WallDepthTier.none, null]) {
    onPlatform('a wall with tier ${tier?.name} has no Depth Effect row', TargetPlatform.iOS, (tester) async {
      await pumpDetail(tester, tier);

      expect(find.byType(DepthEffectRow), findsNothing);
      expect(find.text('Depth Effect'), findsNothing);
    });
  }

  onPlatform('Android has no Depth Effect row, even for an auto wall', TargetPlatform.android, (tester) async {
    await pumpDetail(tester, WallDepthTier.auto);

    expect(find.byType(DepthEffectRow), findsNothing);
  });
}
