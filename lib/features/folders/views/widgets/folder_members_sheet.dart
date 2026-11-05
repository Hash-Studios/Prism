import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_member.dart';
import 'package:Prism/features/folders/domain/repositories/shared_folders_repository.dart';
import 'package:Prism/features/folders/views/folder_invite.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The name shown for a member: the trimmed name, else @username, else a fallback.
String folderMemberName(PublicProfileEntity? profile, AppLocalizations l10n) {
  final String name = profile?.name.trim() ?? '';
  if (name.isNotEmpty) return name;
  final String username = profile?.username.trim() ?? '';
  if (username.isNotEmpty) return '@$username';
  return l10n.foldersUnknownPerson;
}

/// One member's public profile. [placeholder] shows while it loads, so a fallback name never flashes first.
class FolderMemberProfile extends StatelessWidget {
  const FolderMemberProfile({super.key, required this.uid, required this.builder, required this.placeholder});

  final String uid;
  final Widget Function(BuildContext context, PublicProfileEntity? profile) builder;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<PublicProfileRepository>()) return builder(context, null);
    return StreamBuilder<PublicProfileEntity?>(
      stream: getIt<PublicProfileRepository>().watchProfile(uid),
      builder: (context, snapshot) => snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData
          ? placeholder
          : builder(context, snapshot.data),
    );
  }
}

/// Lists the people in [folder]. The owner can invite and remove editors; an editor can leave.
/// Returns true only when the current user left the folder, so the caller can close the folder page.
Future<bool> showFolderMembersSheet(BuildContext context, FolderEntity folder) async {
  final FoldersBloc bloc = context.read<FoldersBloc>();
  final String userId = bloc.state.userId;
  final AppLocalizations l10n = context.l10n;
  final bool owner = folder.isOwnedBy(userId);
  bool left = false;

  await showPrismSheet<void>(
    context,
    builder: (sheetContext) {
      Future<void> removeEditor(String uid, String name) async {
        final bool confirmed = await showPrismConfirm(
          sheetContext,
          title: l10n.foldersRemovePersonTitle(name),
          message: l10n.foldersRemovePersonMessage,
          confirmLabel: l10n.foldersRemovePersonConfirm,
          destructive: true,
        );
        if (!confirmed || !sheetContext.mounted) return;
        final Result<void> result = await getIt<SharedFoldersRepository>().removeMember(folder.id, uid);
        if (result.isFailure) {
          toasts.error(l10n.foldersPeopleFailed);
          return;
        }
        unawaited(analytics.track(FolderMemberRemovedEvent(memberCount: folder.members.length - 1)));
        toasts.success(l10n.foldersPersonRemoved(name));
        bloc.add(FoldersEvent.started(userId: userId));
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      }

      Future<void> leaveFolder() async {
        final bool confirmed = await showPrismConfirm(
          sheetContext,
          title: l10n.foldersLeaveTitle(folder.name),
          message: l10n.foldersLeaveMessage,
          confirmLabel: l10n.foldersLeave,
          destructive: true,
        );
        if (!confirmed || !sheetContext.mounted) return;
        final Result<void> result = await getIt<SharedFoldersRepository>().leave(folder.id);
        if (result.isFailure) {
          toasts.error(l10n.foldersPeopleFailed);
          return;
        }
        unawaited(analytics.track(FolderMemberLeftEvent(memberCount: folder.members.length - 1)));
        toasts.success(l10n.foldersLeft);
        bloc.add(FoldersEvent.started(userId: userId));
        left = true;
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      }

      return PrismSheetBody(
        title: l10n.foldersPeople,
        message: owner ? l10n.foldersPeopleHintOwner(folderMaxEditors) : l10n.foldersPeopleHintEditor,
        actions: <Widget>[
          if (owner)
            PrismButton(
              maxLines: null,
              label: l10n.foldersInvite,
              expand: true,
              onPressed: folder.editors.length >= folderMaxEditors
                  ? null
                  : () => unawaited(inviteToFolder(context, folder, source: 'people_sheet')),
            )
          else
            PrismButton(
              maxLines: null,
              label: l10n.foldersLeave,
              variant: PrismButtonVariant.danger,
              expand: true,
              onPressed: () => unawaited(leaveFolder()),
            ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final FolderMember member in folder.members)
              FolderMemberProfile(
                uid: member.uid,
                placeholder: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.sm),
                  child: Row(
                    children: <Widget>[
                      PrismBone(width: 40, height: 40, radius: PrismRadius.pill),
                      SizedBox(width: PrismSpace.sm),
                      PrismBone(width: 160, height: 16),
                    ],
                  ),
                ),
                builder: (_, profile) {
                  final String name = folderMemberName(profile, l10n);
                  final bool isYou = member.uid == userId;
                  final bool canRemove = owner && member.role == FolderRole.editor;
                  return PrismRow(
                    leading: PrismAvatar(url: profile?.profilePhoto, name: name, size: 40),
                    title: isYou ? l10n.foldersPersonYou(name) : name,
                    subtitle: member.role == FolderRole.owner ? l10n.foldersRoleOwner : l10n.foldersRoleEditor,
                    onTap: () {
                      final StackRouter router = context.router;
                      Navigator.of(sheetContext).pop();
                      unawaited(router.push(ProfileRoute(profileIdentifier: member.uid)));
                    },
                    trailing: canRemove
                        ? PrismButton(
                            maxLines: null,
                            label: l10n.foldersRemovePerson,
                            variant: PrismButtonVariant.ghost,
                            size: PrismButtonSize.compact,
                            onPressed: () => unawaited(removeEditor(member.uid, name)),
                          )
                        : null,
                  );
                },
              ),
          ],
        ),
      );
    },
  );
  return left;
}
