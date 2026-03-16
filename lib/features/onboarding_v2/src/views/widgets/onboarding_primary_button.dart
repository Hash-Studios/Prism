import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onPressed != null && !loading;
    return AnimatedOpacity(
      duration: OnboardingMotion.short,
      opacity: isEnabled ? 1 : OnboardingOpacity.disabledButton,
      child: Material(
        color: OnboardingColors.buttonBackground,
        borderRadius: BorderRadius.circular(OnboardingRadius.cta),
        child: InkWell(
          borderRadius: BorderRadius.circular(OnboardingRadius.cta),
          onTap: isEnabled ? onPressed : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: OnboardingMotion.short,
              child: loading
                  ? const SizedBox(
                      width: OnboardingLayout.loadingIndicatorSize,
                      height: OnboardingLayout.loadingIndicatorSize,
                      child: CircularProgressIndicator(
                        strokeWidth: OnboardingLayout.loadingIndicatorStroke,
                        color: OnboardingColors.buttonText,
                      ),
                    )
                  : Text(label, style: OnboardingTypography.cta),
            ),
          ),
        ),
      ),
    );
  }
}
