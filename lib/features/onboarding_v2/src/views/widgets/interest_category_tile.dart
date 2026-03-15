import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class InterestCategoryTile extends StatelessWidget {
  const InterestCategoryTile({super.key, required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: OnboardingMotion.short,
      curve: OnboardingMotion.emphasized,
      decoration: BoxDecoration(
        color: OnboardingColors.surfaceGlass.withValues(alpha: OnboardingOpacity.cardBase),
        borderRadius: BorderRadius.circular(OnboardingRadius.tile),
      ),
      child: Material(
        color: OnboardingColors.transparent,
        borderRadius: BorderRadius.circular(OnboardingRadius.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(OnboardingRadius.tile),
          onTap: onTap,
          child: AnimatedContainer(
            duration: OnboardingMotion.short,
            curve: OnboardingMotion.emphasized,
            decoration: BoxDecoration(
              color: isSelected
                  ? OnboardingColors.selectionOverlay.withValues(alpha: OnboardingOpacity.selectionOverlay)
                  : OnboardingColors.transparent,
              borderRadius: BorderRadius.circular(OnboardingRadius.tile),
            ),
          ),
        ),
      ),
    );
  }
}
