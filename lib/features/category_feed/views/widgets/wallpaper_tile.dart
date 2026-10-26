import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/depth_tag.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// One wallpaper of a feed grid. It opens the wallpaper detail page and records the tap.
class WallpaperTile extends StatelessWidget {
  const WallpaperTile({
    super.key,
    required this.item,
    required this.index,
    this.memCacheHeight,
    this.crossAxisCount,
    this.onShowLessLikeThis,
    this.sourceContext,
    this.overlay,
    this.impressionSession,
    this.onVisible,
    this.feed,
  });

  final FeedItemEntity item;
  final int index;
  final WallpaperImpressionSession? impressionSession;
  final VoidCallback? onVisible;

  /// The loaded walls of this tile's feed, for swiping between them in the detail page.
  final List<FeedItemEntity>? feed;

  /// Optional decode-height override in physical pixels.
  final int? memCacheHeight;

  /// Offers the personalized feed's real dismiss and undo flow.
  final VoidCallback? onShowLessLikeThis;

  /// Replaces the analytics source context that the tile derives from the wallpaper source.
  final String? sourceContext;

  /// Drawn over the image, for example a positioned tag.
  final Widget? overlay;

  /// Legacy grid-column hint for callers that need a fixed decode size.
  final int? crossAxisCount;

  AnalyticsSurfaceValue get _surface => switch (item.source) {
    WallpaperSource.wallhaven => AnalyticsSurfaceValue.homeWallhavenGrid,
    WallpaperSource.pexels => AnalyticsSurfaceValue.homePexelsGrid,
    _ => AnalyticsSurfaceValue.homeWallpaperGrid,
  };

  String get _sourceContext =>
      sourceContext ??
      switch (item.source) {
        WallpaperSource.wallhaven => 'home_wallhaven_grid_tile',
        WallpaperSource.pexels => 'home_pexels_grid_tile',
        _ => 'home_wallpaper_grid_tile',
      };

  Widget? _overlay() {
    final List<Widget> layers = <Widget>[?overlay, ?depthTagFor(depthTierOf(item))];
    if (layers.length < 2) return layers.firstOrNull;
    return Stack(fit: StackFit.expand, children: layers);
  }

  @override
  Widget build(BuildContext context) {
    final WallpaperImpressionSession session = impressionSession ?? WallpaperImpressionSession.forContext(context);
    final String heroTag = prismHeroTag(Scrollable.maybeOf(context) ?? context, index, item.id);
    final int? columns = crossAxisCount;
    final int? decodeHeight =
        memCacheHeight ??
        (columns == null || columns <= 0 ? null : (MediaQuery.sizeOf(context).width / columns * 3).round());
    return WallpaperImpression(
      itemId: item.id,
      provider: item.source.name,
      surface: _surface,
      source: _sourceContext,
      index: index,
      session: session,
      onVisible: onVisible,
      child: FavouriteWallpaperCard(
        item: item,
        onShowLessLikeThis: onShowLessLikeThis,
        child: PrismWallTile(
          url: item.thumbnailUrl,
          fallbackUrl: item.fullUrl,
          heroTag: heroTag,
          semanticLabel: item.semanticLabel(context.l10n),
          memCacheHeight: decodeHeight,
          overlay: _overlay(),
          onTap: () {
            PrismHaptics.tap();
            unawaited(
              analytics.track(
                SurfaceActionTappedEvent(
                  surface: _surface,
                  action: AnalyticsActionValue.tileOpened,
                  sourceContext: _sourceContext,
                  itemType: ItemTypeValue.wallpaper,
                  itemId: item.id,
                  index: index,
                  requestId: session.requestId,
                  provider: item.source.name,
                ),
              ),
            );
            context.router.push(
              WallpaperDetailRoute(entity: item, heroTag: heroTag, requestId: session.requestId, feed: feed),
            );
          },
        ),
      ),
    );
  }
}
