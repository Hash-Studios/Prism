import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_creator_vm.j.dart';
import 'package:flutter/material.dart';

class CreatorCard extends StatelessWidget {
  const CreatorCard({super.key, required this.creator, required this.onToggle});

  final OnboardingCreatorVm? creator;
  final VoidCallback? onToggle;

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
          onTap: onToggle,
          borderRadius: BorderRadius.circular(OnboardingRadius.tile),
          child: AnimatedContainer(
            duration: OnboardingMotion.short,
            curve: OnboardingMotion.emphasized,
            decoration: BoxDecoration(
              color: (creator?.isSelected ?? false)
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
