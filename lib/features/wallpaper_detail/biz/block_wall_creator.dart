import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/user_blocks/user_block_actions.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/widgets.dart';

const Duration _profileLookupTimeout = Duration(seconds: 8);

/// True when the viewer is signed in and the wall is a Prism wall by someone else. Only then can they block its creator.
bool canBlockWallCreator(FeedItemEntity entity) {
  if (entity.source != WallpaperSource.prism || !app_state.prismUser.loggedIn) return false;
  final String creator = entity.wallpaperCore.authorEmail?.trim().toLowerCase() ?? '';
  return creator.isNotEmpty && creator != app_state.prismUser.email.trim().toLowerCase();
}

/// Finds the creator of [entity], asks to confirm, and blocks them. It reuses the profile screen's block action.
Future<void> blockWallCreator(BuildContext context, FeedItemEntity entity) async {
  final String identifier = entity.wallpaperCore.authorEmail?.trim() ?? '';
  PublicProfileEntity? profile;
  try {
    profile = await getIt<PublicProfileRepository>().watchProfile(identifier).first.timeout(_profileLookupTimeout);
  } catch (error) {
    logger.w('Block creator: could not load the profile', error: error);
  }
  if (profile == null || profile.id.trim().isEmpty || profile.email.trim().isEmpty) {
    toasts.error("Couldn't find this creator. Try again.");
    return;
  }
  if (!context.mounted) return;
  await confirmAndBlockUser(
    context: context,
    targetUserId: profile.id.trim(),
    targetEmail: profile.email.trim(),
    displayName: profile.name,
  );
}
