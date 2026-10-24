import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_blocks/user_block_actions.dart';
import 'package:flutter/widgets.dart';

/// True when the viewer is signed in and the wall has a different, known creator UID.
bool canBlockWallCreator(FeedItemEntity entity) {
  if (BundledWallpapers.isStarter(entity) || entity.source != WallpaperSource.prism || !app_state.prismUser.loggedIn) {
    return false;
  }
  final String creatorUid = entity.wallpaperCore.authorUid?.trim() ?? '';
  return creatorUid.isNotEmpty && creatorUid != app_state.prismUser.id.trim();
}

/// Asks to confirm and blocks the creator by UID. Legacy email-only walls fail closed.
Future<void> blockWallCreator(BuildContext context, FeedItemEntity entity) async {
  if (BundledWallpapers.isStarter(entity)) return;
  final String creatorUid = entity.wallpaperCore.authorUid?.trim() ?? '';
  if (creatorUid.isEmpty || creatorUid == app_state.prismUser.id.trim()) {
    return;
  }
  if (!context.mounted) return;
  await confirmAndBlockUser(
    context: context,
    targetUserId: creatorUid,
    displayName: entity.wallpaperCore.authorName ?? '',
  );
}
