import 'dart:convert';

import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes quick-tile configuration to SharedPreferences using raw string
/// values — no Flutter codec — so that the Android [TileService]s can read
/// them directly from native Kotlin without a running Flutter engine.
class QuickTileConfigService {
  const QuickTileConfigService._();

  // ── Category tile ────────────────────────────────────────────────────────

  /// Persists the category name, wallpaper source and target for the
  /// "Random from Category" quick tile.
  static Future<void> saveCategoryTileConfig({
    required String categoryName,
    required WallpaperSource source,
    required WallpaperTarget target,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PersistenceKeys.quickTileCategoryName, categoryName);
    await prefs.setString(PersistenceKeys.quickTileCategorySource, _sourceToString(source));
    await prefs.setString(PersistenceKeys.quickTileCategoryTarget, _targetToString(target));
  }

  static Future<QuickTileCategoryConfig?> loadCategoryTileConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(PersistenceKeys.quickTileCategoryName);
    final sourceRaw = prefs.getString(PersistenceKeys.quickTileCategorySource);
    final targetRaw = prefs.getString(PersistenceKeys.quickTileCategoryTarget);
    if (name == null || sourceRaw == null || targetRaw == null) return null;
    return QuickTileCategoryConfig(
      categoryName: name,
      source: _sourceFromString(sourceRaw),
      target: _targetFromString(targetRaw),
    );
  }

  // ── WOTD tile ────────────────────────────────────────────────────────────

  /// Persists the wallpaper target for the "Wall of the Day" quick tile.
  static Future<void> saveWotdTileConfig({required WallpaperTarget target}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PersistenceKeys.quickTileWotdTarget, _targetToString(target));
  }

  /// Caches the current WOTD wallpaper URL so the tile can apply it without
  /// a network call.  Call this whenever the WotdBloc emits a success state.
  static Future<void> pushWotdUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PersistenceKeys.quickTileWotdUrl, url);
  }

  static Future<QuickTileWotdConfig?> loadWotdTileConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final targetRaw = prefs.getString(PersistenceKeys.quickTileWotdTarget);
    final url = prefs.getString(PersistenceKeys.quickTileWotdUrl);
    if (targetRaw == null) return null;
    return QuickTileWotdConfig(target: _targetFromString(targetRaw), cachedUrl: url);
  }

  // ── Favourites tile ──────────────────────────────────────────────────────

  /// Persists the wallpaper target for the "Random from Favourites" quick tile.
  static Future<void> saveFavsTileConfig({required WallpaperTarget target}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PersistenceKeys.quickTileFavsTarget, _targetToString(target));
  }

  /// Caches the full list of favourite wallpaper URLs.  Call this whenever
  /// the FavouriteWallsBloc emits a success state.
  static Future<void> pushFavWallUrls(List<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PersistenceKeys.quickTileFavWallUrls, jsonEncode(urls));
  }

  static Future<QuickTileFavsConfig?> loadFavsTileConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final targetRaw = prefs.getString(PersistenceKeys.quickTileFavsTarget);
    final urlsRaw = prefs.getString(PersistenceKeys.quickTileFavWallUrls);
    if (targetRaw == null) return null;
    List<String> urls = const <String>[];
    if (urlsRaw != null) {
      try {
        urls = (jsonDecode(urlsRaw) as List<dynamic>).cast<String>();
      } catch (_) {}
    }
    return QuickTileFavsConfig(target: _targetFromString(targetRaw), wallUrls: urls);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _sourceToString(WallpaperSource source) {
    return switch (source) {
      WallpaperSource.pexels => 'pexels',
      WallpaperSource.wallhaven => 'wallhaven',
      WallpaperSource.prism => 'prism',
      WallpaperSource.downloaded => 'downloaded',
      WallpaperSource.unknown => 'unknown',
    };
  }

  static WallpaperSource _sourceFromString(String raw) {
    return switch (raw) {
      'wallhaven' => WallpaperSource.wallhaven,
      'prism' => WallpaperSource.prism,
      'wall_of_the_day' => WallpaperSource.prism, // legacy: WOTD was always Prism
      'downloaded' => WallpaperSource.downloaded,
      _ => WallpaperSource.pexels,
    };
  }

  static String _targetToString(WallpaperTarget target) {
    return switch (target) {
      WallpaperTarget.home => 'home',
      WallpaperTarget.lock => 'lock',
      WallpaperTarget.both => 'both',
    };
  }

  static WallpaperTarget _targetFromString(String raw) {
    return switch (raw) {
      'home' => WallpaperTarget.home,
      'lock' => WallpaperTarget.lock,
      _ => WallpaperTarget.both,
    };
  }
}

// ── Config value objects ──────────────────────────────────────────────────────

class QuickTileCategoryConfig {
  const QuickTileCategoryConfig({required this.categoryName, required this.source, required this.target});

  final String categoryName;
  final WallpaperSource source;
  final WallpaperTarget target;
}

class QuickTileWotdConfig {
  const QuickTileWotdConfig({required this.target, required this.cachedUrl});

  final WallpaperTarget target;
  final String? cachedUrl;
}

class QuickTileFavsConfig {
  const QuickTileFavsConfig({required this.target, required this.wallUrls});

  final WallpaperTarget target;
  final List<String> wallUrls;
}
