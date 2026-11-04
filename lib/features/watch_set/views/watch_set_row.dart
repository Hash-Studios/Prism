import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/spatial_tag.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/watch_set/views/watch_set_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// True when a watch set can be made from [entity]: it has a download, and it is not a Duo pair.
bool showsWatchSet(FeedItemEntity entity) =>
    !isDuoWallpaper(entity) && (entity.fullUrl.trim().isNotEmpty || entity.source == WallpaperSource.prism);

WatchSetWall watchSetWallOf(FeedItemEntity entity) {
  final WallpaperDisplaySource display = WallpaperDisplaySource.of(entity);
  final WallDesktopVariant? desktop = switch (entity) {
    PrismFeedItem(:final wallpaper) => wallpaper.desktop,
    _ => null,
  };
  return WatchSetWall(
    id: entity.id,
    source: entity.source,
    link: entity.fullUrl,
    previewUrl: display.full.isNotEmpty ? display.full : display.thumbnail,
    isPremium: isPremiumFeedItem(entity, app_state.premiumCollections),
    pixelSize: wallpaperPixelSize(entity.wallpaperCore),
    desktop: desktop,
    depthMapUrl: spatialOf(entity)?.mapUrl,
    creatorName: entity.wallpaperCore.authorName,
  );
}

/// "Watch set" with the other save options of a wall. The subtitle names the desktop item only when the wall has one.
class WatchSetRow extends StatelessWidget {
  const WatchSetRow({super.key, required this.entity});

  final FeedItemEntity entity;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final WatchSetWall wall = watchSetWallOf(entity);
    return PrismRow(
      key: const ValueKey<String>('watch-set-row'),
      icon: Icons.watch_rounded,
      title: l10n.watchSetRowTitle,
      subtitle: wall.desktop == null ? l10n.watchSetRowSubtitle : l10n.watchSetRowSubtitleDesktop,
      padding: EdgeInsets.zero,
      onTap: () => showWatchSetSheet(context, wall),
    );
  }
}
