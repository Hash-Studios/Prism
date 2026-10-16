import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_cover.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

const double _coverHeight = 140;
const double _avatarSize = 84;
const double _avatarRing = 3;
const double _coverScrimHeight = 52;

/// The cover preview and avatar of the profile editor. Both open the image picker.
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
  });

  final String? coverUrl;
  final File? coverFile;
  final String avatarUrl;
  final File? avatarFile;
  final String name;
  final VoidCallback onChangeCover;
  final VoidCallback onRemoveCover;
  final VoidCallback onChangePhoto;

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
                      label: 'Change cover photo',
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
                          tooltip: 'Remove cover photo',
                          onImage: true,
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
              label: 'Change photo',
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
      ],
    );
  }
}

/// The "Edit cover" hint along the bottom of the cover: a black fade, a camera and a white label, always legible over
/// any cover image. It does not take taps; the whole cover is the tap target.
class _EditCoverHint extends StatelessWidget {
  const _EditCoverHint();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: _coverScrimHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.5)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(JamIcons.camera, color: Colors.white.withValues(alpha: 0.85), size: 15),
              const SizedBox(width: 6),
              Text(
                'Edit cover',
                style: PrismTextStyles.caption(
                  context,
                ).copyWith(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
