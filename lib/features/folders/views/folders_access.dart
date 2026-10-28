import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/views/widgets/folder_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Loads the signed-in user's folders once per user, and again after a failed load.
Future<void> ensureFoldersLoaded(BuildContext context) async {
  final String userId = app_state.prismUser.id;
  if (userId.isEmpty) return;
  final FoldersBloc bloc = context.read<FoldersBloc>();
  if (bloc.state.userId == userId && bloc.state.status == LoadStatus.loading) {
    await bloc.stream.firstWhere((state) => state.userId != userId || state.status != LoadStatus.loading);
    return;
  }
  if (bloc.state.userId != userId ||
      bloc.state.status == LoadStatus.initial ||
      bloc.state.status == LoadStatus.failure) {
    await bloc.run((id) => FoldersEvent.started(userId: userId, operationId: id));
  }
}

/// Asks for a name and creates an empty folder. The Library's New folder actions use it.
Future<void> createFolderFromLibrary(BuildContext context) async {
  final FoldersBloc bloc = context.read<FoldersBloc>();
  final String ownerId = app_state.prismUser.id;
  final AppLocalizations l10n = context.l10n;
  final String? name = await showFolderNameSheet(
    context,
    title: l10n.foldersNewFolder,
    actionLabel: l10n.foldersCreate,
  );
  if (name == null || !context.mounted || app_state.prismUser.id != ownerId || bloc.state.userId != ownerId) return;
  final bool ok = await bloc.run((id) => FoldersEvent.createRequested(name: name, operationId: id));
  if (!ok) {
    toasts.error(l10n.foldersUpdateFailed);
    return;
  }
  unawaited(analytics.track(const FolderCreatedEvent(source: 'library', withWall: false)));
}

/// Two or three names for a first folder, from the wall's category and main colour.
List<String> suggestedFolderNames(FavouriteWallEntity wall, AppLocalizations l10n) {
  final String rawCategory = wall.category?.trim() ?? '';
  final String category = rawCategory.isEmpty ? '' : categoryDisplayName(rawCategory, l10n);
  final PrismPaletteColor? colour = _mainColour(wall);
  return <String>{
    // Wallhaven sends raw ids such as "general"; only a real display name makes a good folder name.
    if (category.isNotEmpty && (category != rawCategory || category[0] != category[0].toLowerCase())) category,
    if (colour != null) prismPaletteColorDisplayName(colour, l10n),
    l10n.foldersSuggestionLockScreen,
    l10n.foldersSuggestionHomeScreen,
  }.take(3).toList();
}

PrismPaletteColor? _mainColour(FavouriteWallEntity wall) {
  final String? first = switch (wall) {
    PrismFavouriteWall(:final wallpaper) => wallpaper.colors?.firstOrNull,
    WallhavenFavouriteWall(:final wallpaper) => wallpaper.colors?.firstOrNull,
    _ => null,
  };
  if (first == null || first.isEmpty) return null;
  final PrismPaletteColor? byId = paletteColorById(first);
  if (byId != null) return byId;
  final int? hex = int.tryParse(first.replaceFirst('#', ''), radix: 16);
  return hex == null ? null : nearestPaletteColor(Color(0xFF000000 | hex));
}
