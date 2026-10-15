import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/features/quick_tiles/data/quick_tile_defaults.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('seeds every unconfigured tile so the tiles work before the user taps Save', () async {
    final QuickTileSeed seed = await QuickTileDefaults.seedMissing(category: null, wotd: null, favs: null);

    expect(seed.category.categoryName, categoryDefinitions.first.name);
    expect(seed.category.target, WallpaperTarget.both);
    final category = await QuickTileConfigService.loadCategoryTileConfig();
    expect(category?.categoryName, categoryDefinitions.first.name);
    expect(category?.source, categoryDefinitions.first.source);
    expect((await QuickTileConfigService.loadWotdTileConfig())?.target, WallpaperTarget.both);
    expect((await QuickTileConfigService.loadFavsTileConfig())?.target, WallpaperTarget.both);
  });

  test('keeps a config the user already saved', () async {
    await QuickTileConfigService.saveWotdTileConfig(target: WallpaperTarget.lock);
    final wotd = await QuickTileConfigService.loadWotdTileConfig();

    final QuickTileSeed seed = await QuickTileDefaults.seedMissing(category: null, wotd: wotd, favs: null);

    expect(seed.wotd.target, WallpaperTarget.lock);
    expect((await QuickTileConfigService.loadWotdTileConfig())?.target, WallpaperTarget.lock);
  });

  test('mirrors the Wallhaven category setting as a raw preference', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());

    await QuickTileDefaults.mirrorWallhavenCategories(settings);
    expect((await SharedPreferences.getInstance()).getString(QuickTileDefaults.wallhavenCategoriesKey), '100');

    await settings.set('WHcategories', 111);
    await QuickTileDefaults.mirrorWallhavenCategories(settings);
    expect((await SharedPreferences.getInstance()).getString(QuickTileDefaults.wallhavenCategoriesKey), '111');
  });
}
