import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum WallpaperTarget { home, lock, both }

// ignore: avoid_classes_with_only_static_members
class WallpaperService {
  static Future<bool> setWallpaperFromSource(String source, WallpaperTarget target) async {
    final normalizedSource = _normalizeSource(source);
    final filePath = await _resolveToLocalFile(normalizedSource);
    final wallpaperLocation = _mapTargetToLocation(target);

    final result = await AsyncWallpaper.setWallpaperFromFile(filePath: filePath, wallpaperLocation: wallpaperLocation);

    return result;
  }

  static String _normalizeSource(String source) {
    if (source.startsWith('file://')) {
      return source.substring(7);
    }
    if (source.contains('/0/')) {
      return source.replaceAll('/0//', '/0/');
    }
    if (source.contains('com.hash.prism')) {
      return source;
    }
    return source;
  }

  static Future<String> _resolveToLocalFile(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final file = await DefaultCacheManager().getSingleFile(source);
      return file.path;
    }
    if (source.startsWith('/')) {
      return source;
    }
    return source;
  }

  static int _mapTargetToLocation(WallpaperTarget target) {
    switch (target) {
      case WallpaperTarget.home:
        return AsyncWallpaper.HOME_SCREEN;
      case WallpaperTarget.lock:
        return AsyncWallpaper.LOCK_SCREEN;
      case WallpaperTarget.both:
        return AsyncWallpaper.BOTH_SCREENS;
    }
  }
}
