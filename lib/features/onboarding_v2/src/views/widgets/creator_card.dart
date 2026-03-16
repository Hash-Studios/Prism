import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_creator_vm.j.dart';
import 'package:flutter/material.dart';

class CreatorCard extends StatelessWidget {
  const CreatorCard({super.key, required this.creator, required this.onToggle});

  final OnboardingCreatorVm? creator;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    // eliminates 4 object allocations per card rebuild (3 cards × follow toggles).
    const cardRadius = BorderRadius.all(Radius.circular(OnboardingRadius.tile));
    return AnimatedContainer(
      duration: OnboardingMotion.short,
      curve: OnboardingMotion.emphasized,
      decoration: BoxDecoration(
        color: OnboardingColors.surfaceGlass.withValues(alpha: OnboardingOpacity.cardBase),
        borderRadius: cardRadius,
      ),
      child: Material(
        color: OnboardingColors.transparent,
        borderRadius: cardRadius,
        child: InkWell(
          onTap: onToggle,
          borderRadius: cardRadius,
          child: AnimatedContainer(
            duration: OnboardingMotion.short,
            curve: OnboardingMotion.emphasized,
            decoration: BoxDecoration(
              color: (creator?.isSelected ?? false)
                  ? OnboardingColors.selectionOverlay.withValues(alpha: OnboardingOpacity.selectionOverlay)
                  : OnboardingColors.transparent,
              borderRadius: cardRadius,
            ),
          ),
        ),
      ),
    );
  }
}
