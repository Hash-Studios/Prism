import 'dart:async';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/views/folders_access.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows the signed-in user's folders in a sheet. Null when the sheet closes or the account changes.
Future<FolderEntity?> pickFolder(BuildContext context, String? current) async {
  final FoldersBloc folders = context.read<FoldersBloc>();
  final String sheetOwnerId = app_state.prismUser.id;
  unawaited(ensureFoldersLoaded(context));
  final FolderEntity? picked = await showPrismSheet<FolderEntity>(
    context,
    builder: (sheetContext) => BlocBuilder<FoldersBloc, FoldersState>(
      bloc: folders,
      builder: (pickerContext, state) {
        final AppLocalizations l10n = pickerContext.l10n;
        final bool mine = state.userId.isNotEmpty && state.userId == app_state.prismUser.id;
        final Widget body = switch (state.status) {
          _ when app_state.prismUser.id.isEmpty => SignInPrompt(feature: l10n.foldersSignInFeature),
          LoadStatus.failure when mine => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l10n.foldersLoadError, style: PrismTextStyles.body(pickerContext)),
              const SizedBox(height: PrismSpace.sm),
              PrismButton(
                label: l10n.wallpaperTryAgain,
                variant: PrismButtonVariant.tonal,
                size: PrismButtonSize.compact,
                onPressed: () => unawaited(ensureFoldersLoaded(context)),
              ),
            ],
          ),
          LoadStatus.success when mine && state.folders.isEmpty => Text(
            l10n.wallpaperAutoRotateNoFolders,
            style: PrismTextStyles.body(pickerContext),
          ),
          LoadStatus.success when mine => PrismGroup(
            children: <Widget>[
              for (final FolderEntity folder in state.folders)
                PrismRow(
                  leading: FolderCover(covers: folder.covers, size: 44),
                  title: folder.name,
                  subtitle: l10n.foldersItemCount(folder.itemCount),
                  showChevron: false,
                  trailing: folder.id == current ? const Icon(Icons.check_rounded, size: 20) : null,
                  onTap: () => Navigator.of(sheetContext).pop(folder),
                ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        };
        return PrismSheetBody(title: l10n.wallpaperAutoRotatePickFolder, child: body);
      },
    ),
  );
  if (picked == null || !context.mounted || app_state.prismUser.id != sheetOwnerId || picked.ownerId != sheetOwnerId) {
    return null;
  }
  return picked;
}
