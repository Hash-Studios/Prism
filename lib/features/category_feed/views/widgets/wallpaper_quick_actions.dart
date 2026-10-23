import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_hold_region.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

class WallpaperQuickActionRegion extends StatelessWidget {
  const WallpaperQuickActionRegion({super.key, required this.item, required this.child, this.onShowLessLikeThis});

  final FeedItemEntity item;
  final Widget child;
  final VoidCallback? onShowLessLikeThis;

  @override
  Widget build(BuildContext context) {
    return WallpaperHoldRegion(
      identity: (item.source, item.id, item.thumbnailUrl),
      favouriteLabel: context.l10n.wallpaperFavourite,
      unfavouriteLabel: context.l10n.wallpaperUnfavourite,
      shareLabel: context.l10n.wallpaperShareLink,
      showLessLabel: onShowLessLikeThis == null ? null : context.l10n.wallpaperShowLessLikeThis,
      readIsFavourite: () => getIt<FavoritesLocalDataSource>().isWallFavourite(app_state.prismUser.id, item.id),
      preview: PrismImageTile(
        url: item.thumbnailUrl,
        fallbackUrl: item.fullUrl,
        borderRadius: PrismWallGrid.tileRadius,
      ),
      onAction: (action) => unawaited(_dispatch(context, item, action, onShowLessLikeThis: onShowLessLikeThis)),
      child: child,
    );
  }
}

Future<void> _dispatch(
  BuildContext context,
  FeedItemEntity item,
  WallpaperQuickAction action, {
  VoidCallback? onShowLessLikeThis,
}) async {
  switch (action) {
    case WallpaperQuickAction.favourite:
      final bool saved = getIt<FavoritesLocalDataSource>().isWallFavourite(app_state.prismUser.id, item.id);
      await _toggleFavourite(context, item, favourite: !saved);
    case WallpaperQuickAction.share:
      unawaited(
        copyWallpaperLink(
          item.id,
          item.source,
          item.fullUrl,
          item.thumbnailUrl,
          title: wallpaperPreviewTitle(context.l10n, item),
          core: item.wallpaperCore,
          l10n: context.l10n,
        ),
      );
    case WallpaperQuickAction.showLess:
      onShowLessLikeThis?.call();
  }
}

Future<void> _toggleFavourite(BuildContext context, FeedItemEntity item, {required bool favourite}) async {
  final AppLocalizations l10n = context.l10n;
  bool success = false;
  try {
    success = await context
        .favouriteWallsAdapter(listen: false)
        .favCheck(FavouriteWallEntity.fromFeedItem(item), desired: favourite);
  } catch (error, stackTrace) {
    logger.w('Favourite toggle from the tile menu failed', error: error, stackTrace: stackTrace);
  }
  if (success) {
    toasts.success(favourite ? l10n.wallpaperFavouriteAddedToast : l10n.wallpaperFavouriteRemovedToast);
  } else {
    toasts.error(l10n.coreCouldNotUpdateFavourites);
  }
}
