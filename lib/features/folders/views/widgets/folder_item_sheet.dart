import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/shared_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/folder_members_sheet.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the actions for one wallpaper in a shared folder: who added it, and removing it.
Future<void> showFolderItemSheet(BuildContext context, FolderEntity folder, FavouriteWallEntity wall) async {
  PrismHaptics.tap();
  final FoldersBloc bloc = context.read<FoldersBloc>();
  final String userId = bloc.state.userId;
  final Future<Result<String?>> addedBy = getIt<SharedFoldersRepository>().addedBy(folder.id, folderItemKey(wall));
  await showPrismSheet<void>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    builder: (sheetContext) => PrismSheetBody(
      actions: <Widget>[
        PrismButton(
          maxLines: null,
          label: sheetContext.l10n.foldersRemoveFromFolder,
          variant: PrismButtonVariant.danger,
          expand: true,
          onPressed: () {
            Navigator.of(sheetContext).pop();
            unawaited(_removeFromFolder(context, bloc, folder, wall));
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _addedByLine(addedBy, userId),
          const SizedBox(height: PrismSpace.md),
          SizedBox(
            width: 120,
            height: 160,
            child: PrismWallTile(
              url: wall.thumbnailUrl,
              fallbackUrl: wall.source == WallpaperSource.prism ? null : wall.fullUrl,
              semanticLabel: wallpaperSemanticLabel(wall.authorName, sheetContext.l10n),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _addedByLine(Future<Result<String?>> addedBy, String userId) {
  return FutureBuilder<Result<String?>>(
    future: addedBy,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const PrismBone(width: 140, height: 16);
      final String? uid = snapshot.data?.data;
      if (uid == null || uid.isEmpty) return const SizedBox.shrink();
      final AppLocalizations l10n = context.l10n;
      if (uid == userId) return _line(context, l10n.foldersAddedByYou);
      return FolderMemberProfile(
        uid: uid,
        placeholder: const PrismBone(width: 140, height: 16),
        builder: (context, PublicProfileEntity? owner) =>
            _line(context, l10n.foldersAddedBy(folderMemberName(owner, l10n))),
      );
    },
  );
}

Widget _line(BuildContext context, String text) {
  return Text(text, textAlign: TextAlign.center, softWrap: true, style: PrismTextStyles.rowTitle(context));
}

Future<void> _removeFromFolder(
  BuildContext context,
  FoldersBloc bloc,
  FolderEntity folder,
  FavouriteWallEntity wall,
) async {
  PrismHaptics.impact();
  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await showPrismConfirm(
    context,
    title: l10n.foldersRemoveTitle,
    message: l10n.foldersRemoveMessage,
    confirmLabel: l10n.foldersRemoveConfirm,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  final bool ok = await bloc.run((id) => FoldersEvent.itemRemoved(folderId: folder.id, wall: wall, operationId: id));
  if (ok) {
    toasts.success(l10n.foldersRemoved);
  } else {
    toasts.error(l10n.foldersUpdateFailed);
  }
}
