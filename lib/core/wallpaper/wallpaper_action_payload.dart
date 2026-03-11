import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as p_data;
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as prism_data;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart' as w_data;
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_view.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/profile_walls/views/profile_walls_bloc_adapter.dart';
import 'package:Prism/features/public_profile/views/public_profile_bloc_adapter.dart';
import 'package:flutter/material.dart';

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

  static WallpaperActionPayload? fromSearch({required String? provider, required int index}) {
    if (provider == 'WallHaven') {
      if (index < 0 || index >= w_data.wallsS.length) return null;
      final wall = w_data.wallsS[index];
      return WallpaperActionPayload(
        providerLabel: 'WallHaven',
        title: _capitalized(_safeText(wall.core.category, fallback: 'Wallhaven')),
        subtitle: wall.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          WallpaperActionStat(kind: WallpaperActionStatKind.views, label: 'Views: ${wall.views ?? 0}'),
          WallpaperActionStat(kind: WallpaperActionStatKind.resolution, label: _safeText(wall.core.resolution)),
        ],
        fullUrl: wall.core.fullUrl,
        favouriteWall: WallhavenFavouriteWall(id: wall.id, wallpaper: wall),
        favouriteTrash: false,
        cardTopFactor: 2 / 8,
        cardHeightFactor: 6 / 8,
        titleKind: WallpaperActionTitleKind.category,
        titleColorHex: _lastColorHex(wall.colors),
        sourceContext: 'focused_menu.search.wallhaven',
      );
    }

    if (index < 0 || index >= p_data.wallsPS.length) return null;
    final wall = p_data.wallsPS[index];
    return WallpaperActionPayload(
      providerLabel: 'Pexels',
      title: _safeText(wall.photographer, fallback: 'Pexels'),
      subtitle: wall.id.toUpperCase(),
      stats: <WallpaperActionStat>[
        WallpaperActionStat(kind: WallpaperActionStatKind.resolution, label: _safeText(wall.core.resolution)),
      ],
      fullUrl: wall.core.fullUrl,
      favouriteWall: PexelsFavouriteWall(id: wall.id, wallpaper: wall),
      favouriteTrash: false,
      cardTopFactor: 4 / 10,
      cardHeightFactor: 6 / 10,
      sourceContext: 'focused_menu.search.pexels',
    );
  }

  static WallpaperActionPayload? fromLegacy(BuildContext context, {required String? provider, required int index}) {
    if (provider == 'WallHaven') {
      if (index < 0 || index >= w_data.walls.length) return null;
      final wall = w_data.walls[index];
      return WallpaperActionPayload(
        providerLabel: 'WallHaven',
        title: _capitalized(_safeText(wall.core.category, fallback: 'Wallhaven')),
        subtitle: wall.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          WallpaperActionStat(kind: WallpaperActionStatKind.views, label: 'Views: ${wall.views ?? 0}'),
          WallpaperActionStat(kind: WallpaperActionStatKind.resolution, label: _safeText(wall.core.resolution)),
        ],
        fullUrl: wall.core.fullUrl,
        favouriteWall: WallhavenFavouriteWall(id: wall.id, wallpaper: wall),
        favouriteTrash: false,
        cardTopFactor: 4 / 10,
        cardHeightFactor: 6 / 10,
        titleKind: WallpaperActionTitleKind.category,
        titleColorHex: _lastColorHex(wall.colors),
        sourceContext: 'focused_menu.WallHaven',
      );
    }

    if (provider == 'Prism') {
      final walls = prism_data.subPrismWalls;
      if (walls == null || index < 0 || index >= walls.length) return null;
      final wall = walls[index];
      return WallpaperActionPayload(
        providerLabel: 'Prism',
        title: _safeText(wall.core.authorName, fallback: 'Prism'),
        subtitle: wall.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          WallpaperActionStat(kind: WallpaperActionStatKind.size, label: '${wall.core.sizeBytes ?? 0}'),
          WallpaperActionStat(kind: WallpaperActionStatKind.resolution, label: _safeText(wall.core.resolution)),
        ],
        fullUrl: wall.core.fullUrl,
        favouriteWall: PrismFavouriteWall(id: wall.id, wallpaper: wall),
        favouriteTrash: false,
        cardTopFactor: 4 / 10,
        cardHeightFactor: 6 / 10,
        isPremiumContent: app_state.isPremiumWall(app_state.premiumCollections, wall.collections ?? const <String>[]),
        contentId: wall.id,
        sourceContext: 'focused_menu.Prism',
      );
    }

    if (provider == 'ProfileWall') {
      final walls = context.profileWalls(listen: false);
      if (walls == null || index < 0 || index >= walls.length) return null;
      final wall = walls[index];
      final prismWall = PrismWallpaper(
        core: WallpaperCore(
          id: wall.id,
          source: WallpaperSource.prism,
          fullUrl: wall.wallpaperUrl,
          thumbnailUrl: wall.wallpaperThumb ?? '',
          resolution: wall.resolution,
          sizeBytes: int.tryParse(wall.size ?? '0'),
          createdAt: wall.createdAt,
          authorName: wall.by,
          authorEmail: wall.email,
        ),
        collections: wall.collections,
      );
      return WallpaperActionPayload(
        providerLabel: 'ProfileWall',
        title: _safeText(wall.by, fallback: 'Prism'),
        subtitle: wall.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          WallpaperActionStat(
            kind: WallpaperActionStatKind.size,
            label: _safeText(wall.size, fallback: '0'),
          ),
          WallpaperActionStat(kind: WallpaperActionStatKind.resolution, label: _safeText(wall.resolution)),
        ],
        fullUrl: wall.wallpaperUrl,
        favouriteWall: PrismFavouriteWall(id: wall.id, wallpaper: prismWall),
        favouriteTrash: false,
        cardTopFactor: 4 / 10,
        cardHeightFactor: 6 / 10,
        isPremiumContent: app_state.isPremiumWall(app_state.premiumCollections, wall.collections as List? ?? []),
        contentId: wall.id,
        sourceContext: 'focused_menu.ProfileWall',
      );
    }

    if (provider == 'UserProfileWall') {
      final walls = context.publicProfileAdapter().userProfileWalls;
      if (walls == null || index < 0 || index >= walls.length) return null;
      final wall = walls[index];
      final prismWall = PrismWallpaper(
        core: WallpaperCore(
          id: wall.id,
          source: WallpaperSource.prism,
          fullUrl: wall.wallpaperUrl,
          thumbnailUrl: wall.wallpaperThumb ?? '',
          resolution: wall.resolution,
          sizeBytes: int.tryParse(wall.size ?? '0'),
          createdAt: wall.createdAt,
          authorName: wall.by,
          authorEmail: wall.email,
        ),
        collections: wall.collections,
      );
      return WallpaperActionPayload(
        providerLabel: 'UserProfileWall',
        title: _safeText(wall.by, fallback: 'Prism'),
        subtitle: wall.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          WallpaperActionStat(
            kind: WallpaperActionStatKind.size,
            label: _safeText(wall.size, fallback: '0'),
          ),
          WallpaperActionStat(kind: WallpaperActionStatKind.resolution, label: _safeText(wall.resolution)),
        ],
        fullUrl: wall.wallpaperUrl,
        favouriteWall: PrismFavouriteWall(id: wall.id, wallpaper: prismWall),
        favouriteTrash: false,
        cardTopFactor: 4 / 10,
        cardHeightFactor: 6 / 10,
        isPremiumContent: app_state.isPremiumWall(app_state.premiumCollections, wall.collections as List? ?? []),
        contentId: wall.id,
        sourceContext: 'focused_menu.UserProfileWall',
      );
    }

    if (provider == 'Pexels') {
      if (index < 0 || index >= p_data.wallsP.length) return null;
      final wall = p_data.wallsP[index];
      return WallpaperActionPayload(
        providerLabel: 'Pexels',
        title: _safeText(wall.photographer, fallback: 'Pexels'),
        subtitle: wall.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          WallpaperActionStat(kind: WallpaperActionStatKind.resolution, label: _safeText(wall.core.resolution)),
        ],
        fullUrl: wall.core.fullUrl,
        favouriteWall: PexelsFavouriteWall(id: wall.id, wallpaper: wall),
        favouriteTrash: false,
        cardTopFactor: 4 / 10,
        cardHeightFactor: 6 / 10,
        sourceContext: 'focused_menu.Pexels',
      );
    }

    if (provider == 'Liked') {
      final liked = context.favouriteWallsAdapter(listen: false).liked;
      if (liked == null || index < 0 || index >= liked.length) return null;
      final wall = liked[index];
      final isWallhaven = wall.provider == 'WallHaven';
      final isPrism = wall.provider == 'Prism';
      final isPexels = wall.provider == 'Pexels';
      return WallpaperActionPayload(
        providerLabel: 'Liked',
        title: isWallhaven
            ? _capitalized(_safeText(wall.category, fallback: 'Wallhaven'))
            : _safeText(wall.photographer),
        subtitle: wall.id.toUpperCase(),
        stats: <WallpaperActionStat>[
          if (isWallhaven)
            WallpaperActionStat(
              kind: WallpaperActionStatKind.views,
              label: 'Views: ${_safeText(wall.views, fallback: '0')}',
            ),
          if (isPrism)
            WallpaperActionStat(
              kind: WallpaperActionStatKind.size,
              label: _safeText(wall.size, fallback: '0'),
            ),
          WallpaperActionStat(kind: WallpaperActionStatKind.resolution, label: _safeText(wall.resolution)),
        ],
        fullUrl: wall.url,
        favouriteWall: wall,
        favouriteTrash: true,
        cardTopFactor: isPexels ? 1 / 2 : 2 / 8,
        cardHeightFactor: isPexels ? 1 / 2 : 6 / 8,
        isPremiumContent: app_state.isPremiumWall(app_state.premiumCollections, wall.collections),
        contentId: wall.id,
        sourceContext: 'focused_menu.Liked',
      );
    }

    if (index < 0 || index >= p_data.wallsC.length) return null;
    final wall = p_data.wallsC[index];
    return WallpaperActionPayload(
      providerLabel: provider ?? 'Pexels',
      title: _safeText(wall.photographer, fallback: 'Pexels'),
      subtitle: wall.id.toUpperCase(),
      stats: <WallpaperActionStat>[
        WallpaperActionStat(kind: WallpaperActionStatKind.resolution, label: _safeText(wall.core.resolution)),
      ],
      fullUrl: wall.core.fullUrl,
      favouriteWall: PexelsFavouriteWall(id: wall.id, wallpaper: wall),
      favouriteTrash: false,
      cardTopFactor: 2 / 8,
      cardHeightFactor: 6 / 8,
      sourceContext: 'focused_menu.${provider ?? 'Pexels'}',
    );
  }

  static String _safeText(String? value, {String fallback = '-'}) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _capitalized(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static String? _lastColorHex(List<String>? colors) {
    if (colors == null || colors.isEmpty) return null;
    final hex = colors.last.toUpperCase().replaceAll('#', '');
    if (hex.length != 6) return null;
    return hex;
  }
}
