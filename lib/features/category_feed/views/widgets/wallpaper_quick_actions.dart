import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

enum _QuickAction { favourite, share, set, showLess }

/// The long-press menu for a wallpaper tile. Every grid opens this one sheet.
///
/// [onShowLessLikeThis] adds the "Show less like this" row. Only the home feed passes it.
Future<void> showWallpaperQuickActions(
  BuildContext context,
  FeedItemEntity item, {
  VoidCallback? onShowLessLikeThis,
  String? requestId,
}) async {
  final bool isFavourite = getIt<FavoritesLocalDataSource>().isWallFavourite(app_state.prismUser.id, item.id);
  final _QuickAction? action = await showPrismSheet<_QuickAction>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
            title: Text(isFavourite ? context.l10n.wallpaperUnfavourite : context.l10n.wallpaperFavourite),
            onTap: () => Navigator.of(sheetContext).pop(_QuickAction.favourite),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: Text(context.l10n.wallpaperShareLink),
            onTap: () => Navigator.of(sheetContext).pop(_QuickAction.share),
          ),
          if (!hideSetWallpaperUi)
            ListTile(
              leading: const Icon(Icons.wallpaper_rounded),
              title: Text(context.l10n.wallpaperSetAsWallpaper),
              onTap: () => Navigator.of(sheetContext).pop(_QuickAction.set),
            ),
          if (onShowLessLikeThis != null)
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(context.l10n.wallpaperShowLessLikeThis),
              subtitle: Text(context.l10n.wallpaperFewerLikeThisConfirmation),
              onTap: () => Navigator.of(sheetContext).pop(_QuickAction.showLess),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _QuickAction.favourite:
      await _toggleFavourite(context, item, favourite: !isFavourite);
    case _QuickAction.share:
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
    case _QuickAction.set:
      try {
        await SetWallpaperFlow.run(
          context,
          url: item.fullUrl,
          thumbnailUrl: item.thumbnailUrl,
          wallpaperId: item.id,
          wallpaperSource: item.source,
          entryPoint: 'wallpaper_quick_actions',
          requestId: requestId,
        );
      } catch (error, stackTrace) {
        logger.e('Set wallpaper from the tile menu failed', error: error, stackTrace: stackTrace);
      }
    case _QuickAction.showLess:
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
