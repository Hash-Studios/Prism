import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // eliminates 4 object allocations per tile rebuild.
    const tileRadius = BorderRadius.all(Radius.circular(OnboardingRadius.tile));
    const selectedTileRadius = BorderRadius.all(Radius.circular(OnboardingRadius.tile - 2));
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: OnboardingMotion.short,
      curve: OnboardingMotion.emphasized,
      decoration: BoxDecoration(
        color: OnboardingColors.surfaceGlass.withValues(alpha: OnboardingOpacity.cardBase),
        borderRadius: tileRadius,
        border: isSelected ? Border.all(color: accent, width: 2) : null,
      ),
      child: Material(
        color: OnboardingColors.transparent,
        borderRadius: tileRadius,
        child: InkWell(
          borderRadius: tileRadius,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          child: ClipRRect(
            borderRadius: isSelected ? selectedTileRadius : tileRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                AnimatedContainer(
                  duration: OnboardingMotion.short,
                  curve: OnboardingMotion.emphasized,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? OnboardingColors.selectionOverlay.withValues(alpha: OnboardingOpacity.selectionOverlay)
                        : OnboardingColors.transparent,
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedOpacity(
                    duration: OnboardingMotion.short,
                    opacity: isSelected ? 1.0 : 0.0,
                    child: AnimatedScale(
                      duration: OnboardingMotion.short,
                      curve: OnboardingMotion.emphasized,
                      scale: isSelected ? 1.0 : 0.5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
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
