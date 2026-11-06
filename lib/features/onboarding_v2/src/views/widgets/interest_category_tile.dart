import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/data/categories/category_cover.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const double _ringWidth = 3;

/// One category to pick on the interests step: a photo with its name over a bottom scrim. Selected tiles get a 3 point
/// white ring and a white tick disc. Onboarding runs before the user picks an accent, so the selection uses no accent
/// and cannot clash with one.
class InterestCategoryTile extends StatelessWidget {
  const InterestCategoryTile({
    super.key,
    required this.name,
    required this.isSelected,
    required this.onTap,
    this.imageUrl,
  });

  final String name;
  final String? imageUrl;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String displayName = categoryDisplayName(name, context.l10n);
    const tileRadius = BorderRadius.all(Radius.circular(OnboardingRadius.tile));
    const innerRadius = BorderRadius.all(Radius.circular(OnboardingRadius.tile - _ringWidth));
    final shortMotion = context.motion(OnboardingMotion.short);
    return AnimatedContainer(
      duration: shortMotion,
      curve: OnboardingMotion.emphasized,
      decoration: BoxDecoration(
        color: OnboardingColors.surfaceGlass.withValues(alpha: OnboardingOpacity.cardBase),
        borderRadius: tileRadius,
        border: Border.all(
          color: isSelected ? OnboardingColors.white : OnboardingColors.transparent,
          width: _ringWidth,
        ),
      ),
      child: Material(
        color: OnboardingColors.transparent,
        borderRadius: tileRadius,
        child: InkWell(
          borderRadius: tileRadius,
          onTap: () {
            PrismHaptics.selection();
            onTap();
          },
          child: ClipRRect(
            borderRadius: innerRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final int decodeWidth = (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round();
                      final String? asset = bundledCoverAsset(imageUrl!);
                      if (asset != null) return Image.asset(asset, cacheWidth: decodeWidth, fit: BoxFit.cover);
                      return CachedNetworkImage(
                        imageUrl: imageUrl!,
                        cacheManager: PrismImageCache.instance,
                        memCacheWidth: decodeWidth,
                        fit: BoxFit.cover,
                        fadeInDuration: shortMotion,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                AnimatedContainer(
                  duration: shortMotion,
                  curve: OnboardingMotion.emphasized,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? OnboardingColors.selectionOverlay.withValues(alpha: OnboardingOpacity.selectionOverlay)
                        : OnboardingColors.transparent,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    // The label sits on any photo, so the lower 55% darkens to 0.75.
                    gradient: LinearGradient(
                      begin: const Alignment(0, -0.1),
                      end: Alignment.bottomCenter,
                      colors: [
                        OnboardingColors.black.withValues(alpha: 0),
                        OnboardingColors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontFamily: OnboardingTypography.sans,
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 1))],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedOpacity(
                    duration: shortMotion,
                    opacity: isSelected ? 1.0 : 0.0,
                    child: AnimatedScale(
                      duration: shortMotion,
                      curve: OnboardingMotion.emphasized,
                      scale: isSelected ? 1.0 : 0.5,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: OnboardingColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: OnboardingColors.black.withValues(alpha: 0.3), blurRadius: 4)],
                        ),
                        child: const Icon(Icons.check_rounded, color: OnboardingColors.black, size: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
