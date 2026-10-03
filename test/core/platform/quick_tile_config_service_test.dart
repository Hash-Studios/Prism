import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invalid native targets do not become both home and lock', () async {
    for (final target in <String>['', 'invalid', 'HOME']) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.quickTileCategoryName: 'Nature',
        PersistenceKeys.quickTileCategorySource: 'pexels',
        PersistenceKeys.quickTileCategoryTarget: target,
        PersistenceKeys.quickTileWotdTarget: target,
        PersistenceKeys.quickTileFavsTarget: target,
      });

      expect(await QuickTileConfigService.loadCategoryTileConfig(), isNull);
      expect(await QuickTileConfigService.loadWotdTileConfig(), isNull);
      expect(await QuickTileConfigService.loadFavsTileConfig(), isNull);
    }
  });

  test('malformed favourites are discarded before reaching the native tile', () async {
    for (final urls in <String>['["https://example.com/wall.jpg", 1]', '{"url": "wall"}', 'invalid']) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.quickTileFavsTarget: 'home',
        PersistenceKeys.quickTileFavWallUrls: urls,
      });

      final config = await QuickTileConfigService.loadFavsTileConfig();
      expect(config?.target, WallpaperTarget.home);
      expect(config?.wallUrls, isEmpty);
    }
  });

  test('unsupported stored category sources do not become a Pexels category', () async {
    for (final source in <String>['unknown', 'downloaded', 'prism', 'wall_of_the_day', 'typo']) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.quickTileCategoryName: 'Nature',
        PersistenceKeys.quickTileCategorySource: source,
        PersistenceKeys.quickTileCategoryTarget: 'both',
      });

      expect(await QuickTileConfigService.loadCategoryTileConfig(), isNull);
    }
  });

  test('supported category sources round-trip through native preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    for (final source in <WallpaperSource>[WallpaperSource.pexels, WallpaperSource.wallhaven]) {
      await QuickTileConfigService.saveCategoryTileConfig(
        categoryName: 'Nature',
        source: source,
        target: WallpaperTarget.lock,
      );
      final config = await QuickTileConfigService.loadCategoryTileConfig();
      expect(config?.categoryName, 'Nature');
      expect(config?.source, source);
      expect(config?.target, WallpaperTarget.lock);
    }
  });
}
