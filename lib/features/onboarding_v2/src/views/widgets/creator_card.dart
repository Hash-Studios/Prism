import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CreatorCard extends StatelessWidget {
  const CreatorCard({super.key, required this.creator, required this.isSelected, required this.onToggle});

  final OnboardingStarterCreatorEntity creator;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    const cardRadius = BorderRadius.all(Radius.circular(OnboardingRadius.tile));
    const innerRadius = BorderRadius.all(Radius.circular(OnboardingRadius.tile - 2));
    final accent = Theme.of(context).colorScheme.primary;

    return PressScale(
      child: AnimatedContainer(
        duration: OnboardingMotion.short,
        curve: OnboardingMotion.emphasized,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: cardRadius,
          border: isSelected ? Border.all(color: accent, width: 2) : null,
        ),
        child: Material(
          color: OnboardingColors.transparent,
          borderRadius: cardRadius,
          child: InkWell(
            onTap: () {
              PrismHaptics.selection();
              onToggle();
            },
            borderRadius: cardRadius,
            child: ClipRRect(
              borderRadius: isSelected ? innerRadius : cardRadius,
              child: _CardContent(creator: creator, isSelected: isSelected, accent: accent),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.creator, required this.isSelected, required this.accent});

  final OnboardingStarterCreatorEntity creator;
  final bool isSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final previews = creator.previewUrls.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                backgroundImage: creator.photoUrl.isNotEmpty ? CachedNetworkImageProvider(creator.photoUrl) : null,
                child: creator.photoUrl.isEmpty
                    ? Text(
                        creator.name.isNotEmpty ? creator.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontFamily: OnboardingTypography.sans,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (creator.name.isNotEmpty)
                      Text(
                        creator.name,
                        style: const TextStyle(
                          fontFamily: OnboardingTypography.sans,
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${formatCompactCount(creator.followerCount)} followers',
                      style: TextStyle(
                        fontFamily: OnboardingTypography.sans,
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              _FollowButton(isSelected: isSelected, accent: accent),
            ],
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 12, 12),
            child: Row(
              children: List.generate(5, (i) {
                final url = i < previews.length ? previews[i] : null;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _PreviewTile(url: url),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isSelected, required this.accent});

  final bool isSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.motion(const Duration(milliseconds: 180)),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? accent : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedSwitcher(
        duration: context.motion(const Duration(milliseconds: 140)),
        child: Text(
          isSelected ? 'following' : 'follow',
          key: ValueKey(isSelected),
          style: OnboardingTypography.cta.copyWith(
            color: Colors.white,
            fontSize: 13,
            fontFamily: OnboardingTypography.sans,
          ),
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(10));
    return ClipRRect(
      borderRadius: radius,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: (_, _, _) => _emptyTile,
            )
          : _emptyTile,
    );
  }

  static final _emptyTile = DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: const BorderRadius.all(Radius.circular(10)),
    ),
  );
}
