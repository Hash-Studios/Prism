import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

const String _previewLink =
    'https://us-central1-123.cloudfunctions.net/wallpaperPreview?id=clock-wall&thumb=https%3A%2F%2Fimg.test%2Fthumb.jpg';

FeedItemEntity _prism() => const FeedItemEntity.prism(
  id: 'clock-wall',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'clock-wall',
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/original.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
    ),
  ),
);

FeedItemEntity _wallhaven() => const FeedItemEntity.wallhaven(
  id: 'wallhaven-ab',
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: 'wallhaven-ab',
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://w.wallhaven.cc/full/ab/wallhaven-ab.jpg',
      thumbnailUrl: 'https://th.wallhaven.cc/small/ab/wallhaven-ab.jpg',
    ),
  ),
);

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('iOS phone preview link', () {
    setUpFavouriteCounts();

    late SettingsLocalDataSource settings;
    late OfflineAssetFixture offlineAssets;

    setUp(() async {
      offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
      offlineAssets.install();
      settings = SettingsLocalDataSource(InMemoryLocalStore());
      getIt.registerSingleton<SettingsLocalDataSource>(settings);
      getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
      getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
      getIt.registerSingleton<DownloadedWallIndex>(DownloadedWallIndex(settings));
    });

    tearDown(() async {
      await offlineAssets.dispose();
      await getIt.reset();
    });

    Future<void> pumpDetail(WidgetTester tester, FeedItemEntity entity) async {
      final _MockWallpaperDetailBloc bloc = _MockWallpaperDetailBloc();
      final WallpaperDetailLoaded state = WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: entity,
        paletteLoading: false,
      );
      whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state.copyWith(panelCollapsed: false));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(entity: entity),
          ),
        ),
      );
      await tester.pump();
    }

    Future<ClockOverlay> openPreview(WidgetTester tester, FeedItemEntity entity) async {
      await pumpDetail(tester, entity);
      await tester.tap(find.byTooltip(AppLocalizationsEn().wallpaperPreviewOnScreen));
      await tester.pumpAndSettle();
      return tester.widget<ClockOverlay>(find.byType(ClockOverlay));
    }

    testWidgets('the iOS phone preview of a Prism wall shows its display derivative, not the thumbnail', (
      tester,
    ) async {
      final ClockOverlay overlay = await openPreview(tester, _prism());

      expect(overlay.link, _previewLink);
      expect(overlay.link, isNot('https://img.test/thumb.jpg'));
      expect(overlay.link, isNot(contains('original.jpg')));
      expect(overlay.thumbnailUrl, 'https://img.test/thumb.jpg');
      expect(overlay.file, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the iOS phone preview of a Wallhaven wall shows its full URL', (tester) async {
      final ClockOverlay overlay = await openPreview(tester, _wallhaven());

      expect(overlay.link, 'https://w.wallhaven.cc/full/ab/wallhaven-ab.jpg');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('setScreenPreviewLink for the Android Set screen', () {
    const String thumb = 'https://img.test/thumb.jpg';
    const String previewW1 =
        'https://us-central1-123.cloudfunctions.net/wallpaperPreview?id=w1&thumb=https%3A%2F%2Fimg.test%2Fthumb.jpg';

    test('a Prism request with no url previews the display derivative', () {
      expect(
        setScreenPreviewLink(
          const SetScreenRequest(
            url: '',
            thumbnailUrl: thumb,
            wallpaperId: 'w1',
            wallpaperSource: WallpaperSource.prism,
          ),
        ),
        previewW1,
      );
    });

    test('a Prism request with the original url still previews, never the original', () {
      expect(
        setScreenPreviewLink(
          const SetScreenRequest(
            url: 'https://img.test/original.jpg',
            thumbnailUrl: thumb,
            wallpaperId: 'w1',
            wallpaperSource: WallpaperSource.prism,
          ),
        ),
        previewW1,
      );
    });

    test('a local file is passed through as is', () {
      expect(
        setScreenPreviewLink(
          const SetScreenRequest(
            url: '/tmp/wall.png',
            thumbnailUrl: thumb,
            wallpaperId: 'w1',
            wallpaperSource: WallpaperSource.prism,
          ),
        ),
        '/tmp/wall.png',
      );
    });

    test('a Wallhaven request uses its url', () {
      expect(
        setScreenPreviewLink(
          const SetScreenRequest(
            url: 'https://w.wallhaven.cc/full/ab/wallhaven-ab.jpg',
            thumbnailUrl: 'https://th.wallhaven.cc/small/ab/wallhaven-ab.jpg',
            wallpaperId: 'wallhaven-ab',
            wallpaperSource: WallpaperSource.wallhaven,
          ),
        ),
        'https://w.wallhaven.cc/full/ab/wallhaven-ab.jpg',
      );
    });

    test('a non-Prism request with an empty url falls back to the thumbnail', () {
      expect(
        setScreenPreviewLink(
          const SetScreenRequest(
            url: '',
            thumbnailUrl: thumb,
            wallpaperId: 'w1',
            wallpaperSource: WallpaperSource.wallhaven,
          ),
        ),
        thumb,
      );
    });
  });
}
