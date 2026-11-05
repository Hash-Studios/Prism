import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_cover.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

const double _coverHeight = 140;
const double _avatarSize = 84;
const double _avatarRing = 3;

/// The cover preview and avatar of the profile editor. Both open the image picker.
/// A "Remove photo" button sits next to the avatar while [onRemovePhoto] is set.
class EditProfileHeader extends StatelessWidget {
  const EditProfileHeader({
    super.key,
    required this.coverUrl,
    required this.coverFile,
    required this.avatarUrl,
    required this.avatarFile,
    required this.name,
    required this.onChangeCover,
    required this.onRemoveCover,
    required this.onChangePhoto,
    this.onRemovePhoto,
  });

  final String? coverUrl;
  final File? coverFile;
  final String avatarUrl;
  final File? avatarFile;
  final String name;
  final VoidCallback onChangeCover;
  final VoidCallback onRemoveCover;
  final VoidCallback onChangePhoto;
  final VoidCallback? onRemovePhoto;

  /// Key of the tap target that opens the cover picker. It is the whole cover.
  static const Key changeCoverKey = ValueKey<String>('edit_profile_change_cover');

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    const double avatarFull = _avatarSize + 2 * _avatarRing;
    final bool hasCustomCover = coverFile != null || ProfileCover.hasCover(coverUrl);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: avatarFull / 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PrismRadius.lg),
              child: SizedBox(
                height: _coverHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Semantics(
                      button: true,
                      label: context.l10n.accountChangeCoverPhoto,
                      excludeSemantics: true,
                      onTap: onChangeCover,
                      child: GestureDetector(
                        key: changeCoverKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: onChangeCover,
                        child: ProfileCover(url: coverUrl, file: coverFile),
                      ),
                    ),
                    const _EditCoverHint(),
                    if (hasCustomCover)
                      Positioned(
                        top: PrismSpace.xxs,
                        right: PrismSpace.xxs,
                        child: PrismIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: context.l10n.accountRemoveCoverPhoto,
                          glass: true,
                          onPressed: onRemoveCover,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: PrismSpace.page + PrismSpace.md,
          bottom: 0,
          child: PressScale(
            child: Semantics(
              button: true,
              label: context.l10n.accountChangePhoto,
              excludeSemantics: true,
              onTap: onChangePhoto,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChangePhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(_avatarRing),
                      decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                      child: avatarFile != null
                          ? ClipOval(
                              child: Image.file(
                                avatarFile!,
                                width: _avatarSize,
                                height: _avatarSize,
                                fit: BoxFit.cover,
                              ),
                            )
                          : PrismAvatar(url: avatarUrl, name: name, size: _avatarSize),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                        child: Icon(Icons.photo_camera_rounded, size: 16, color: cs.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onRemovePhoto != null)
          Positioned(
            left: PrismSpace.page + PrismSpace.md + avatarFull + PrismSpace.xs,
            bottom: 0,
            child: PrismButton(
              label: context.l10n.accountRemovePhoto,
              icon: Icons.delete_outline_rounded,
              variant: PrismButtonVariant.ghost,
              size: PrismButtonSize.compact,
              onPressed: onRemovePhoto,
            ),
          ),
      ],
    );
  }
}

/// The "Edit cover" hint at the bottom end of the cover: a camera and an ink label on a glass pill (near-opaque page
/// colour, soft shadow), legible over any cover image. It does not take taps; the whole cover is the tap target.
class _EditCoverHint extends StatelessWidget {
  const _EditCoverHint();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PositionedDirectional(
      bottom: PrismSpace.xs,
      end: PrismSpace.xs,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(PrismRadius.pill),
            boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 1))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.photo_camera_rounded, color: cs.onSurface, size: 16),
                const SizedBox(width: 6),
                Text(
                  context.l10n.accountEditCover,
                  style: PrismTextStyles.caption(context).copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
