import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';

enum WallpaperActionStatKind { views, resolution, size, likes }

enum WallpaperActionTitleKind { camera, category }

final class WallpaperActionStat {
  const WallpaperActionStat({required this.kind, required this.label});

  final WallpaperActionStatKind kind;
  final String label;
}

final class WallpaperActionPayload {
  const WallpaperActionPayload({
    required this.providerLabel,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.fullUrl,
    required this.favouriteWall,
    required this.favouriteTrash,
    required this.cardTopFactor,
    required this.cardHeightFactor,
    this.titleKind = WallpaperActionTitleKind.camera,
    this.titleColorHex,
    this.isPremiumContent = false,
    this.contentId,
    this.sourceContext,
  });

  final String providerLabel;
  final String title;
  final String subtitle;
  final List<WallpaperActionStat> stats;
  final String fullUrl;
  final FavouriteWallEntity favouriteWall;
  final bool favouriteTrash;
  final double cardTopFactor;
  final double cardHeightFactor;
  final WallpaperActionTitleKind titleKind;
  final String? titleColorHex;
  final bool isPremiumContent;
  final String? contentId;
  final String? sourceContext;
}

final class WallpaperActionPayloadAdapter {
  const WallpaperActionPayloadAdapter._();

  static WallpaperActionPayload fromFeedItem(FeedItemEntity item, {String? sourceContext}) {
    return switch (item) {
      PrismFeedItem prism => WallpaperActionPayload(
        providerLabel: 'Prism',
        title: _safeText(prism.wallpaper.core.authorName, fallback: 'Prism'),
        subtitle: prism.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          WallpaperActionStat(kind: WallpaperActionStatKind.size, label: '${prism.wallpaper.core.sizeBytes ?? 0}'),
          WallpaperActionStat(
            kind: WallpaperActionStatKind.resolution,
            label: _safeText(prism.wallpaper.core.resolution),
          ),
        ],
        fullUrl: prism.wallpaper.fullUrl,
        favouriteWall: PrismFavouriteWall(id: prism.id, wallpaper: prism.wallpaper),
        favouriteTrash: false,
        cardTopFactor: 4 / 10,
        cardHeightFactor: 6 / 10,
        isPremiumContent: app_state.isPremiumWall(
          app_state.premiumCollections,
          prism.wallpaper.collections ?? const <String>[],
        ),
        contentId: prism.id,
        sourceContext: sourceContext ?? 'focused_menu.feed.prism',
      ),
      WallhavenFeedItem wallhaven => WallpaperActionPayload(
        providerLabel: 'WallHaven',
        title: _capitalized(_safeText(wallhaven.wallpaper.core.category, fallback: 'Wallhaven')),
        subtitle: wallhaven.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          WallpaperActionStat(kind: WallpaperActionStatKind.views, label: 'Views: ${wallhaven.wallpaper.views ?? 0}'),
          WallpaperActionStat(
            kind: WallpaperActionStatKind.resolution,
            label: _safeText(wallhaven.wallpaper.core.resolution),
          ),
        ],
        fullUrl: wallhaven.wallpaper.fullUrl,
        favouriteWall: WallhavenFavouriteWall(id: wallhaven.id, wallpaper: wallhaven.wallpaper),
        favouriteTrash: false,
        cardTopFactor: 4 / 10,
        cardHeightFactor: 6 / 10,
        titleKind: WallpaperActionTitleKind.category,
        titleColorHex: _lastColorHex(wallhaven.wallpaper.colors),
        sourceContext: sourceContext ?? 'focused_menu.feed.wallhaven',
      ),
      PexelsFeedItem pexels => WallpaperActionPayload(
        providerLabel: 'Pexels',
        title: _safeText(pexels.wallpaper.photographer, fallback: 'Pexels'),
        subtitle: pexels.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          WallpaperActionStat(
            kind: WallpaperActionStatKind.resolution,
            label: _safeText(pexels.wallpaper.core.resolution),
          ),
        ],
        fullUrl: pexels.wallpaper.fullUrl,
        favouriteWall: PexelsFavouriteWall(id: pexels.id, wallpaper: pexels.wallpaper),
        favouriteTrash: false,
        cardTopFactor: 4 / 10,
        cardHeightFactor: 6 / 10,
        sourceContext: sourceContext ?? 'focused_menu.feed.pexels',
      ),
    };
  }

  static String _safeText(String? value, {String fallback = '-'}) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _capitalized(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static String? _lastColorHex(List<String>? colors) {
    if (colors == null || colors.isEmpty) {
      return null;
    }
    final hex = colors.last.toUpperCase().replaceAll('#', '');
    if (hex.length != 6) {
      return null;
    }
    return hex;
  }
}
