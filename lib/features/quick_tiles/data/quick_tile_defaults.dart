import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gives the quick tiles a working config the first time the user opens the settings, and mirrors the
/// Wallhaven category setting to a raw preference that the native shuffle tile can read.
class QuickTileDefaults {
  const QuickTileDefaults._();

  static const String wallhavenCategoriesKey = 'quick_tile.wallhaven.categories';

  static Future<void> mirrorWallhavenCategories(SettingsLocalDataSource settings) async {
    final int categories = settings.get<int>('WHcategories', defaultValue: 100);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(wallhavenCategoriesKey, categories.toString());
  }

  /// Saves the default config for every tile that has none. Returns what was saved.
  static Future<QuickTileSeed> seedMissing({
    required QuickTileCategoryConfig? category,
    required QuickTileWotdConfig? wotd,
    required QuickTileFavsConfig? favs,
  }) async {
    final CategoryDefinition first = categoryDefinitions.first;
    final QuickTileCategoryConfig seededCategory =
        category ??
        QuickTileCategoryConfig(categoryName: first.name, source: first.source, target: WallpaperTarget.both);
    final QuickTileWotdConfig seededWotd =
        wotd ?? const QuickTileWotdConfig(target: WallpaperTarget.both, cachedUrl: null);
    final QuickTileFavsConfig seededFavs =
        favs ?? const QuickTileFavsConfig(target: WallpaperTarget.both, wallUrls: <String>[]);
    await Future.wait(<Future<void>>[
      if (category == null)
        QuickTileConfigService.saveCategoryTileConfig(
          categoryName: seededCategory.categoryName,
          source: seededCategory.source,
          target: seededCategory.target,
        ),
      if (wotd == null) QuickTileConfigService.saveWotdTileConfig(target: seededWotd.target),
      if (favs == null) QuickTileConfigService.saveFavsTileConfig(target: seededFavs.target),
    ]);
    return QuickTileSeed(category: seededCategory, wotd: seededWotd, favs: seededFavs);
  }
}

class QuickTileSeed {
  const QuickTileSeed({required this.category, required this.wotd, required this.favs});

  final QuickTileCategoryConfig category;
  final QuickTileWotdConfig wotd;
  final QuickTileFavsConfig favs;
}
