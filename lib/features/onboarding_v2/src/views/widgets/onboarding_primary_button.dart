import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  /// Optional leading icon (e.g. the Apple logo for "Continue with Apple").
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: PressScale(
        enabled: isEnabled,
        child: AnimatedOpacity(
          duration: context.motion(OnboardingMotion.short),
          opacity: isEnabled ? 1 : OnboardingOpacity.disabledButton,
          child: Material(
            color: OnboardingColors.buttonBackground,
            borderRadius: BorderRadius.circular(OnboardingRadius.cta),
            child: InkWell(
              borderRadius: BorderRadius.circular(OnboardingRadius.cta),
              onTap: isEnabled
                  ? () {
                      PrismHaptics.tap();
                      onPressed?.call();
                    }
                  : null,
              child: Center(
                child: AnimatedSwitcher(
                  duration: context.motion(OnboardingMotion.short),
                  child: loading
                      ? const SizedBox(
                          width: OnboardingLayout.loadingIndicatorSize,
                          height: OnboardingLayout.loadingIndicatorSize,
                          child: CircularProgressIndicator(
                            strokeWidth: OnboardingLayout.loadingIndicatorStroke,
                            color: OnboardingColors.buttonText,
                          ),
                        )
                      : ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: icon == null
                                  ? Text(label, style: OnboardingTypography.cta)
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 18, color: OnboardingColors.buttonText),
                                        const SizedBox(width: 8),
                                        Text(label, style: OnboardingTypography.cta),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
