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
    final Duration short = context.motion(OnboardingMotion.short);
    final BorderRadius radius = BorderRadius.circular(OnboardingRadius.cta);
    // Disabled stays a solid white pill with 55% black text (about 4.6:1 on the gradient), not a faded-out button.
    final Color fill = isEnabled
        ? OnboardingColors.buttonBackground
        : OnboardingColors.buttonBackground.withValues(alpha: OnboardingOpacity.disabledButtonFill);
    final Color ink = isEnabled
        ? OnboardingColors.buttonText
        : OnboardingColors.buttonText.withValues(alpha: OnboardingOpacity.disabledButtonText);
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: PressScale(
        enabled: isEnabled,
        child: AnimatedContainer(
          duration: short,
          decoration: BoxDecoration(color: fill, borderRadius: radius),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: isEnabled
                  ? () {
                      PrismHaptics.tap();
                      onPressed?.call();
                    }
                  : null,
              child: Center(
                child: AnimatedSwitcher(
                  duration: short,
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
                                  ? Text(label, style: OnboardingTypography.cta.copyWith(color: ink))
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 18, color: ink),
                                        const SizedBox(width: 8),
                                        Text(label, style: OnboardingTypography.cta.copyWith(color: ink)),
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
