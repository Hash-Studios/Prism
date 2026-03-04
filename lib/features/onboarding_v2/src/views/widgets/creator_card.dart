import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_creator_vm.j.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class CreatorCard extends StatelessWidget {
  const CreatorCard({super.key, required this.creator, required this.onToggle});

  final OnboardingCreatorVm creator;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = creator.isSelected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? colorScheme.primary : Colors.transparent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Row(
                children: [
                  _Avatar(photoUrl: creator.photoUrl, name: creator.name),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creator.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatFollowerCount(creator.followerCount),
                          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 120),
                      child: isSelected
                          ? const Text(
                              'Following',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                            )
                          : const Text(
                              'Follow',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (creator.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                creator.bio,
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (creator.previewUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: Row(
                  children: [
                    ...creator.previewUrls
                        .take(2)
                        .map(
                          (e) => [
                            Expanded(
                              child: _PreviewThumbnail(
                                imageUrl: e,
                                onTap: () => context.pushRoute(ProfileRoute(profileIdentifier: creator.email)),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        )
                        .flattenedToList,
                    if (creator.previewUrls.length > 2) ...[
                      Expanded(
                        child: _PreviewThumbnail(
                          imageUrl: creator.previewUrls[2],
                          showMoreOverlay: true,
                          onTap: () => context.pushRoute(ProfileRoute(profileIdentifier: creator.email)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static String _formatFollowerCount(int count) {
    if (count >= 1000000) {
      final value = count / 1000000;
      final formatted = value == value.truncate() ? '${value.truncate()}M' : '${value.toStringAsFixed(1)}M';
      return '$formatted followers';
    }
    if (count >= 1000) {
      final value = count / 1000;
      final formatted = value == value.truncate() ? '${value.truncate()}K' : '${value.toStringAsFixed(1)}K';
      return '$formatted followers';
    }
    return '$count followers';
  }
}

class _PreviewThumbnail extends StatelessWidget {
  const _PreviewThumbnail({required this.imageUrl, required this.onTap, this.showMoreOverlay = false});

  final String imageUrl;
  final VoidCallback onTap;
  final bool showMoreOverlay;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: const Color(0xFF2A2A2A)),
              errorWidget: (_, _, _) => const ColoredBox(
                color: Color(0xFF2A2A2A),
                child: Icon(Icons.broken_image_outlined, size: 20, color: Colors.white24),
              ),
            ),
            if (showMoreOverlay) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(JamIcons.chevron_right, color: Colors.white, size: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.name});

  final String photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF2A2A2A),
      child: photoUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => _Initials(name: name),
              ),
            )
          : _Initials(name: name),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      initial,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
    );
  }
}
