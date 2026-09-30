import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A suggested creator: avatar, name, follower count, a Follow toggle and a strip of three of their wallpapers.
class CreatorCard extends StatelessWidget {
  const CreatorCard({super.key, required this.creator, required this.isSelected, required this.onToggle});

  final OnboardingStarterCreatorEntity creator;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final List<String> previews = creator.previewUrls.take(3).toList();
    final String followers = '${formatCompactCount(creator.followerCount)} followers';
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              PrismAvatar(url: creator.photoUrl, name: creator.name),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (creator.name.isNotEmpty)
                      Text(
                        creator.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.cardTitle(context),
                      ),
                    Text(followers, style: PrismTextStyles.caption(context)),
                  ],
                ),
              ),
              const SizedBox(width: PrismSpace.sm),
              PrismButton(
                label: isSelected ? 'Following' : 'Follow',
                icon: isSelected ? Icons.check_rounded : null,
                variant: isSelected ? PrismButtonVariant.ghost : PrismButtonVariant.tonal,
                size: PrismButtonSize.compact,
                onPressed: onToggle,
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          Row(
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: PrismSpace.xs),
                Expanded(child: _Thumb(url: i < previews.length ? previews[i] : null)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final Widget empty = ColoredBox(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06));
    final String? src = url;
    return AspectRatio(
      aspectRatio: 0.75,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.xs),
        child: src == null || src.isEmpty
            ? empty
            : CachedNetworkImage(
                imageUrl: src,
                fit: BoxFit.cover,
                fadeInDuration: context.motion(PrismDurations.fast),
                placeholder: (_, _) => empty,
                errorWidget: (_, _, _) => empty,
              ),
      ),
    );
  }
}
