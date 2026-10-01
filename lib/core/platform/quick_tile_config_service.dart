import 'dart:convert';

import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/logger/logger.dart';
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
    if (source != WallpaperSource.pexels && source != WallpaperSource.wallhaven) {
      throw ArgumentError.value(source, 'source', 'Category tiles support Pexels and Wallhaven');
    }
    final prefs = await SharedPreferences.getInstance();
    await _setString(prefs, PersistenceKeys.quickTileCategoryName, categoryName);
    await _setString(prefs, PersistenceKeys.quickTileCategorySource, source.name);
    await _setString(prefs, PersistenceKeys.quickTileCategoryTarget, target.name);
    await persistPexelsApiKey();
  }

  static Future<void> persistPexelsApiKey() async {
    final String key = Env.normalize(Env.pexelsApiKey);
    if (key.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await _setString(prefs, PersistenceKeys.quickTilePexelsApiKey, key);
  }

  static Future<QuickTileCategoryConfig?> loadCategoryTileConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(PersistenceKeys.quickTileCategoryName);
    final sourceRaw = prefs.getString(PersistenceKeys.quickTileCategorySource);
    final targetRaw = prefs.getString(PersistenceKeys.quickTileCategoryTarget);
    if (name == null || sourceRaw == null || targetRaw == null) return null;
    final source = switch (sourceRaw) {
      'pexels' => WallpaperSource.pexels,
      'wallhaven' => WallpaperSource.wallhaven,
      _ => null,
    };
    final target = _targetFromString(targetRaw);
    if (source == null || target == null) return null;
    return QuickTileCategoryConfig(categoryName: name, source: source, target: target);
  }

  // ── WOTD tile ────────────────────────────────────────────────────────────

  /// Persists the wallpaper target for the "Wall of the Day" quick tile.
  static Future<void> saveWotdTileConfig({required WallpaperTarget target}) async {
    final prefs = await SharedPreferences.getInstance();
    await _setString(prefs, PersistenceKeys.quickTileWotdTarget, target.name);
  }

  /// Caches the current WOTD wallpaper URL so the tile can apply it without
  /// a network call.  Call this whenever the WotdBloc emits a success state.
  static Future<void> pushWotdUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await _setString(prefs, PersistenceKeys.quickTileWotdUrl, url);
    await persistPexelsApiKey();
  }

  static Future<QuickTileWotdConfig?> loadWotdTileConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final targetRaw = prefs.getString(PersistenceKeys.quickTileWotdTarget);
    final url = prefs.getString(PersistenceKeys.quickTileWotdUrl);
    if (targetRaw == null) return null;
    final target = _targetFromString(targetRaw);
    if (target == null) return null;
    return QuickTileWotdConfig(target: target, cachedUrl: url);
  }

  // ── Favourites tile ──────────────────────────────────────────────────────

  /// Persists the wallpaper target for the "Random from Favourites" quick tile.
  static Future<void> saveFavsTileConfig({required WallpaperTarget target}) async {
    final prefs = await SharedPreferences.getInstance();
    await _setString(prefs, PersistenceKeys.quickTileFavsTarget, target.name);
  }

  /// Caches the full list of favourite wallpaper URLs.  Call this whenever
  /// the FavouriteWallsBloc emits a success state.
  static Future<void> pushFavWallUrls(List<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    await _setString(prefs, PersistenceKeys.quickTileFavWallUrls, jsonEncode(urls));
    await persistPexelsApiKey();
  }

  static Future<QuickTileFavsConfig?> loadFavsTileConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final targetRaw = prefs.getString(PersistenceKeys.quickTileFavsTarget);
    final urlsRaw = prefs.getString(PersistenceKeys.quickTileFavWallUrls);
    if (targetRaw == null) return null;
    final target = _targetFromString(targetRaw);
    if (target == null) return null;
    List<String> urls = const <String>[];
    if (urlsRaw != null) {
      try {
        urls = (jsonDecode(urlsRaw) as List<Object?>).cast<String>().toList(growable: false);
      } catch (error, stackTrace) {
        logger.w('Failed to decode favourites tile urls', error: error, stackTrace: stackTrace);
      }
    }
    return QuickTileFavsConfig(target: target, wallUrls: urls);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<void> _setString(SharedPreferences prefs, String key, String value) async {
    if (!await prefs.setString(key, value)) {
      throw StateError('Quick tile settings could not be persisted');
    }
  }

  static WallpaperTarget? _targetFromString(String raw) {
    return switch (raw) {
      'home' => WallpaperTarget.home,
      'lock' => WallpaperTarget.lock,
      'both' => WallpaperTarget.both,
      _ => null,
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
