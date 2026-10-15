import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WallpaperTile extends StatelessWidget {
  const WallpaperTile({
    super.key,
    required this.item,
    required this.index,
    this.memCacheHeight,
    this.crossAxisCount,
    this.quickActions = false,
    this.onShowLessLikeThis,
    this.sourceContext,
  });

  final FeedItemEntity item;
  final int index;
  final int? memCacheHeight;

  /// Long press opens the quick actions sheet, and a heart marks a wallpaper that is already a favourite.
  final bool quickActions;

  /// Adds "Show less like this" to the quick actions sheet.
  final VoidCallback? onShowLessLikeThis;

  /// Replaces the analytics source context that the tile derives from the wallpaper source.
  final String? sourceContext;

  /// When null, uses the app's standard grid (3 columns portrait, 5 landscape).
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

  @override
  Widget build(BuildContext context) {
    final columns = crossAxisCount ?? wallpaperGridColumns(MediaQuery.sizeOf(context).width);
    final height = memCacheHeight ?? gridTileDecodeHeight(context, crossAxisCount: columns);
    final String heroTag = prismHeroTag(Scrollable.maybeOf(context) ?? context, index, item.id);
    return Semantics(
      button: true,
      label: item.semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
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
                ),
              ),
            );
            context.router.push(WallpaperDetailRoute(entity: item, heroTag: heroTag));
          },
          onLongPress: quickActions
              ? () {
                  PrismHaptics.impact();
                  unawaited(showWallpaperQuickActions(context, item, onShowLessLikeThis: onShowLessLikeThis));
                }
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              HeroMode(
                enabled: !context.reduceMotion,
                child: Hero(
                  tag: heroTag,
                  child: PrismImageTile(url: item.thumbnailUrl, fallbackUrl: item.fullUrl, memCacheHeight: height),
                ),
              ),
              if (quickActions) _FavouriteBadge(itemId: item.id),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small heart on a tile whose wallpaper is already in the user's favourites. It never takes touches.
class _FavouriteBadge extends StatelessWidget {
  const _FavouriteBadge({required this.itemId});

  final String itemId;

  static const String _label = 'In your favourites';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavouriteWallsBloc, FavouriteWallsState>(
      buildWhen: (previous, current) =>
          previous.completedOperationId != current.completedOperationId ||
          previous.items.length != current.items.length,
      builder: (context, _) {
        if (!getIt<FavoritesLocalDataSource>().isWallFavourite(app_state.prismUser.id, itemId)) {
          return const SizedBox.shrink();
        }
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return Positioned.directional(
          textDirection: Directionality.of(context),
          end: 6,
          bottom: 6,
          child: IgnorePointer(
            child: Semantics(
              label: _label,
              child: Tooltip(
                message: _label,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.85), shape: BoxShape.circle),
                  child: SizedBox.square(
                    dimension: 24,
                    child: Icon(Icons.favorite_rounded, size: 14, color: scheme.secondary),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
