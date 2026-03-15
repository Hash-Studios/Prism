import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum WallpaperTarget { home, lock, both }

// ignore: avoid_classes_with_only_static_members
class WallpaperService {
  static Future<bool> setWallpaperFromSource(String source, WallpaperTarget target) async {
    final normalizedSource = _normalizeSource(source);
    final filePath = await _resolveToLocalFile(normalizedSource);
    final request = aw.WallpaperRequest(
      target: _mapTargetToLocation(target),
      sourceType: aw.WallpaperSourceType.file,
      source: filePath,
    );

    final result = await aw.AsyncWallpaper.setWallpaper(request).timeout(
      const Duration(seconds: 30),
    );

    return result.isSuccess;
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
      final file = await DefaultCacheManager().getSingleFile(source).timeout(
        const Duration(seconds: 30),
      );
      return file.path;
    }
    if (source.startsWith('/')) {
      return source;
    }
    return source;
  }

  static aw.WallpaperTarget _mapTargetToLocation(WallpaperTarget target) {
    switch (target) {
      case WallpaperTarget.home:
        return aw.WallpaperTarget.home;
      case WallpaperTarget.lock:
        return aw.WallpaperTarget.lock;
      case WallpaperTarget.both:
        return aw.WallpaperTarget.both;
    }
  }
}
