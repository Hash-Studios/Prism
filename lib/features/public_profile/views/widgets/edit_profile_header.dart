import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_cover.dart';
import 'package:flutter/material.dart';

const double _coverHeight = 140;
const double _avatarSize = 84;
const double _avatarRing = 3;

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
                    ProfileCover(url: coverUrl, file: coverFile),
                    Positioned(
                      right: PrismSpace.xs,
                      bottom: PrismSpace.xs,
                      child: _OnImagePill(
                        icon: Icons.photo_camera_rounded,
                        label: 'Change cover',
                        onTap: onChangeCover,
                      ),
                    ),
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

/// A pill button for use on top of an image: dark translucent fill, white label, on every theme.
class _OnImagePill extends StatelessWidget {
  const _OnImagePill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Semantics(
        button: true,
        label: 'Change cover photo',
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(PrismRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(label, style: PrismTextStyles.button.copyWith(fontSize: 14, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
