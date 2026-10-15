import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
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

/// Scale a wall needs to cover the screen, as in "Fill screen". Above 1 the image is enlarged.
double _coverScale(Size wall, Size screen) => math.max(screen.width / wall.width, screen.height / wall.height);

/// Largest enlargement that still looks sharp. Above it the wall is low resolution for the screen.
const double _maxSharpScale = 1.25;

/// True when "Fill screen" has to enlarge the wall by more than 25%. Orientation counts: a wide wall is cropped to fit.
bool isLowResolutionForScreen(WallpaperCore core, Size screenPixels) {
  final Size? wall = wallpaperPixelSize(core);
  if (wall == null || screenPixels.isEmpty) return false;
  return _coverScale(wall, screenPixels) > _maxSharpScale;
}

/// True when the wall is wider than it is tall, so "Fill screen" crops its sides.
bool isLandscapeWallpaper(WallpaperCore core) {
  final Size? wall = wallpaperPixelSize(core);
  return wall != null && wall.width > wall.height;
}

/// Short warnings for the set sheet and the details panel. Empty when the wall suits the screen.
List<String> wallpaperResolutionNotes(WallpaperCore core, Size screenPixels) => <String>[
  if (isLowResolutionForScreen(core, screenPixels)) 'Low resolution for your screen',
  if (isLandscapeWallpaper(core)) 'Landscape wallpaper: the sides will be cropped',
];

/// Headline for a wall: the creator's title, else "Wallpaper by" and the creator name. An email is never shown.
String wallpaperTitle(FeedItemEntity item) {
  final String title = item.maybeWhen(prism: (_, wall) => wall.title?.trim(), orElse: () => null) ?? '';
  if (title.isNotEmpty) return title;
  final String name = item.wallpaperCore.authorName?.trim() ?? '';
  if (name.isNotEmpty && !name.contains('@')) return 'Wallpaper by $name';
  return item.source == WallpaperSource.prism ? 'Wallpaper by Prism creator' : _defaultPreviewTitle;
}

/// Title for the link preview. Same as the headline.
String wallpaperPreviewTitle(FeedItemEntity item) => wallpaperTitle(item);

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
