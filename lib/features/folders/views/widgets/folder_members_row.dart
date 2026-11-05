import 'dart:async';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/views/folder_invite.dart';
import 'package:Prism/features/folders/views/widgets/folder_members_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The people in a folder: an overlapping avatar stack and a count. It opens the members sheet. The owner also sees
/// an Invite button.
class FolderMembersRow extends StatelessWidget {
  const FolderMembersRow({super.key, required this.folder, required this.userId});

  final FolderEntity folder;
  final String userId;

  static const int _maxAvatars = 4;
  static const double _avatarSize = 32;
  static const double _ringWidth = 2;
  static const double _overlap = 22;

  Future<void> _openMembers(BuildContext context) async {
    final bool left = await showFolderMembersSheet(context, folder);
    if (left && context.mounted) unawaited(context.router.maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int count = folder.members.length;
    final int extra = count - _maxAvatars;
    final int shown = count > _maxAvatars ? _maxAvatars : count;
    final int slots = shown + (extra > 0 ? 1 : 0);
    const double ringed = _avatarSize + _ringWidth * 2;
    final double stackWidth = ringed + (slots - 1) * _overlap;

    Widget ring(Widget child) => Container(
      padding: const EdgeInsets.all(_ringWidth),
      decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surface),
      child: child,
    );

    final Widget stack = SizedBox(
      width: stackWidth,
      height: ringed,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < shown; i++)
            Positioned(
              left: i * _overlap,
              top: 0,
              child: ring(
                FolderMemberProfile(
                  uid: folder.members[i].uid,
                  placeholder: const PrismBone(width: _avatarSize, height: _avatarSize, radius: PrismRadius.pill),
                  builder: (_, profile) =>
                      PrismAvatar(url: profile?.profilePhoto, name: folderMemberName(profile, l10n), size: _avatarSize),
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown * _overlap,
              top: 0,
              child: ring(
                Container(
                  width: _avatarSize,
                  height: _avatarSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surfaceContainerHigh),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('+$extra', style: PrismTextStyles.caption(context)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final Widget people = Semantics(
      button: true,
      label: l10n.foldersPeopleButtonLabel(count),
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(_openMembers(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                stack,
                const SizedBox(width: PrismSpace.xs),
                Flexible(child: Text(l10n.foldersPeopleCount(count), style: PrismTextStyles.caption(context))),
              ],
            ),
          ),
        ),
      ),
    );

    return Wrap(
      spacing: PrismSpace.sm,
      runSpacing: PrismSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        people,
        if (folder.isOwnedBy(userId))
          PrismButton(
            maxLines: null,
            label: l10n.foldersInvite,
            variant: PrismButtonVariant.tonal,
            size: PrismButtonSize.compact,
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => unawaited(inviteToFolder(context, folder, source: 'folder_header')),
          ),
      ],
    );
  }
}
