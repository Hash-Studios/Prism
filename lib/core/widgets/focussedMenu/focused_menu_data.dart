import 'package:Prism/core/wallpaper/wallpaper_action_payload.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

typedef FocusedMenuTapAction = Future<void> Function(BuildContext context);

final class FocusedMenuStat {
  const FocusedMenuStat({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

final class FocusedMenuData {
  const FocusedMenuData({
    required this.providerLabel,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.fullUrl,
    required this.favouriteWall,
    required this.favouriteTrash,
    required this.cardTopFactor,
    required this.cardHeightFactor,
    this.titleIcon = JamIcons.camera,
    this.titleBackgroundColor,
    this.titleForegroundColor = Colors.white,
    this.onTitleTap,
    this.isPremiumContent = false,
    this.contentId,
    this.sourceContext,
  });

  final String providerLabel;
  final String title;
  final String subtitle;
  final List<FocusedMenuStat> stats;
  final String fullUrl;
  final FavouriteWallEntity favouriteWall;
  final bool favouriteTrash;
  final double cardTopFactor;
  final double cardHeightFactor;
  final IconData titleIcon;
  final Color? titleBackgroundColor;
  final Color titleForegroundColor;
  final FocusedMenuTapAction? onTitleTap;
  final bool isPremiumContent;
  final String? contentId;
  final String? sourceContext;
}

final class FocusedMenuDataAdapter {
  const FocusedMenuDataAdapter._();

  static FocusedMenuData fromPayload(WallpaperActionPayload payload) {
    final titleColor = _hexColor(payload.titleColorHex);
    return FocusedMenuData(
      providerLabel: payload.providerLabel,
      title: payload.title,
      subtitle: payload.subtitle,
      stats: payload.stats.map(_mapStat).toList(growable: false),
      fullUrl: payload.fullUrl,
      favouriteWall: payload.favouriteWall,
      favouriteTrash: payload.favouriteTrash,
      cardTopFactor: payload.cardTopFactor,
      cardHeightFactor: payload.cardHeightFactor,
      titleIcon: payload.titleKind == WallpaperActionTitleKind.category ? JamIcons.ordered_list : JamIcons.camera,
      titleBackgroundColor: titleColor,
      titleForegroundColor: _colorOn(titleColor),
      isPremiumContent: payload.isPremiumContent,
      contentId: payload.contentId,
      sourceContext: payload.sourceContext,
    );
  }

  static FocusedMenuData fromFeedItem(FeedItemEntity item, {String? sourceContext}) {
    final payload = WallpaperActionPayloadAdapter.fromFeedItem(item, sourceContext: sourceContext);
    return fromPayload(payload);
  }

  static FocusedMenuData? fromSearch({required String? provider, required int index}) {
    final payload = WallpaperActionPayloadAdapter.fromSearch(provider: provider, index: index);
    if (payload == null) return null;
    return fromPayload(payload);
  }

  static FocusedMenuData? fromLegacy(BuildContext context, {required String? provider, required int index}) {
    final payload = WallpaperActionPayloadAdapter.fromLegacy(context, provider: provider, index: index);
    if (payload == null) return null;
    return fromPayload(payload);
  }

  static FocusedMenuStat _mapStat(WallpaperActionStat stat) {
    final icon = switch (stat.kind) {
      WallpaperActionStatKind.views => JamIcons.eye,
      WallpaperActionStatKind.resolution => JamIcons.set_square,
      WallpaperActionStatKind.size => JamIcons.save,
      WallpaperActionStatKind.likes => JamIcons.heart_f,
    };
    return FocusedMenuStat(icon: icon, label: stat.label);
  }

  static Color? _hexColor(String? hex) {
    if (hex == null || hex.length != 6) return null;
    return Color(int.parse('FF$hex', radix: 16));
  }

  static Color _colorOn(Color? color) {
    final target = color ?? Colors.black;
    return target.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
