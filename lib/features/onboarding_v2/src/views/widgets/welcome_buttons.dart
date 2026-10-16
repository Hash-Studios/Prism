import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// How an [WelcomePrimaryButton] sits on the welcome art.
enum WelcomeButtonStyle {
  /// White fill, black label: the main choice.
  solid,

  /// A frosted white tint with a hairline border and a white label.
  glass,
}

/// A full-width, 56 high pill button for the welcome art. The theme does not apply on top of a photo, so it uses
/// white and black.
class WelcomePrimaryButton extends StatelessWidget {
  const WelcomePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.style = WelcomeButtonStyle.solid,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool loading;

  /// Optional leading icon, for example the Apple logo.
  final IconData? icon;
  final WelcomeButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !loading;
    final bool solid = style == WelcomeButtonStyle.solid;
    final Color fg = solid ? Colors.black : Colors.white;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.pill);
    final TextStyle textStyle = PrismTextStyles.button.copyWith(fontSize: 16, color: fg);
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: PressScale(
        enabled: isEnabled,
        child: AnimatedOpacity(
          duration: context.motion(PrismDurations.fast),
          opacity: onPressed == null ? 0.55 : 1,
          child: Material(
            color: solid ? Colors.white : Colors.white.withValues(alpha: 0.14),
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: solid ? BorderSide.none : BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: isEnabled
                  ? () {
                      PrismHaptics.tap();
                      onPressed!();
                    }
                  : null,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: loading
                      ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
                      : ExcludeSemantics(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                Icon(icon, size: 22, color: fg),
                                const SizedBox(width: PrismSpace.xs),
                              ],
                              Flexible(
                                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle),
                              ),
                            ],
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

/// A text-only button for the welcome art: white at 85%, 44 high.
class WelcomeTextButton extends StatelessWidget {
  const WelcomeTextButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: TextButton(
        onPressed: () {
          PrismHaptics.tap();
          onPressed();
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.85),
          minimumSize: const Size.fromHeight(44),
          textStyle: PrismTextStyles.button,
          splashFactory: NoSplash.splashFactory,
        ),
        child: Text(label),
      ),
    );
  }
}
