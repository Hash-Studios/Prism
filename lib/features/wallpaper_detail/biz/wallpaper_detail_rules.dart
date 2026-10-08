import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

const int _maxPreviewCacheWidth = 2160;
const int _maxTags = 10;
const String _defaultPreviewTitle = 'Wallpaper on Prism';

/// Only Prism walls can sit in a premium collection. Wallhaven and Pexels walls are never premium.
bool isPremiumFeedItem(FeedItemEntity item, List<String> premiumCollections) {
  return item.maybeWhen(
    prism: (_, wall) => isPremiumWall(premiumCollections, wall.collections ?? const <String>[]),
    orElse: () => false,
  );
}

/// Decode width for a full-screen preview: the screen width in device pixels, capped so 4K originals stay cheap.
int previewCacheWidth(double logicalWidth, double devicePixelRatio) {
  final int pixels = (logicalWidth * devicePixelRatio).round();
  return math.max(1, math.min(_maxPreviewCacheWidth, pixels));
}

final RegExp _resolutionPattern = RegExp(r'^\s*(\d+)\s*[x×]\s*(\d+)\s*$', caseSensitive: false);

/// Pixel size from the core fields, or from a "1080x1920" style resolution string.
Size? wallpaperPixelSize(WallpaperCore core) {
  final int? width = core.width;
  final int? height = core.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return Size(width.toDouble(), height.toDouble());
  }
  final RegExpMatch? match = _resolutionPattern.firstMatch(core.resolution ?? '');
  if (match == null) return null;
  final int w = int.parse(match.group(1)!);
  final int h = int.parse(match.group(2)!);
  return w > 0 && h > 0 ? Size(w.toDouble(), h.toDouble()) : null;
}

/// True when the wall has fewer pixels than the screen on either side. Orientation does not matter.
bool isLowResolutionForScreen(WallpaperCore core, Size screenPixels) {
  final Size? wall = wallpaperPixelSize(core);
  if (wall == null) return false;
  return math.min(wall.width, wall.height) < math.min(screenPixels.width, screenPixels.height) ||
      math.max(wall.width, wall.height) < math.max(screenPixels.width, screenPixels.height);
}

/// Title for the link preview: the creator when known, else a plain default.
String wallpaperPreviewTitle(FeedItemEntity item) {
  final String name = item.wallpaperCore.authorName?.trim() ?? '';
  return name.isEmpty ? _defaultPreviewTitle : 'Wallpaper by $name';
}

/// Tags shown as chips: trimmed, unique, case-insensitive, capped.
List<String> wallpaperTags(FeedItemEntity item) {
  final List<String> raw = item.when(
    prism: (_, wall) => wall.tags ?? const <String>[],
    wallhaven: (_, wall) => wall.tags ?? const <String>[],
    pexels: (_, _) => const <String>[],
  );
  final Set<String> seen = <String>{};
  final List<String> tags = <String>[];
  for (final String tag in raw) {
    final String clean = tag.trim();
    if (clean.isEmpty || !seen.add(clean.toLowerCase())) continue;
    tags.add(clean);
    if (tags.length == _maxTags) break;
  }
  return tags;
}
