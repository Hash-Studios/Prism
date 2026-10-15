import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// "By continuing you agree to the Terms and Privacy policy": a 24 point checkbox with a 44 point tap target and links
/// to both documents. It sits on the welcome art, so it is white.
class OnboardingTermsRow extends StatelessWidget {
  const OnboardingTermsRow({
    super.key,
    required this.accepted,
    required this.onChanged,
    required this.legalTap,
    required this.privacyTap,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;

  /// Opens the terms. It is set on the link text.
  final TapGestureRecognizer legalTap;

  /// Opens the privacy policy. It is set on the link text.
  final TapGestureRecognizer privacyTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle text = PrismTextStyles.body(context).copyWith(color: Colors.white.withValues(alpha: 0.85));
    void toggle() {
      PrismHaptics.selection();
      onChanged(!accepted);
    }

    return Semantics(
      container: true,
      checked: accepted,
      label: 'By continuing you agree to the Terms and Privacy policy',
      onTap: toggle,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        const CustomSemanticsAction(label: 'Open Terms'): () => legalTap.onTap?.call(),
        const CustomSemanticsAction(label: 'Open Privacy policy'): () => privacyTap.onTap?.call(),
      },
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: <Widget>[
                _Check(accepted: accepted),
                const SizedBox(width: PrismSpace.sm),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: text,
                      children: <InlineSpan>[
                        const TextSpan(text: 'By continuing you agree to the '),
                        TextSpan(
                          text: 'Terms',
                          style: text.copyWith(decoration: TextDecoration.underline, color: Colors.white),
                          recognizer: legalTap,
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy policy',
                          style: text.copyWith(decoration: TextDecoration.underline, color: Colors.white),
                          recognizer: privacyTap,
                        ),
                      ],
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

class _Check extends StatelessWidget {
  const _Check({required this.accepted});

  final bool accepted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.motion(PrismDurations.fast),
      curve: PrismCurves.enter,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: accepted ? Colors.white : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(PrismRadius.xs),
        border: Border.all(color: Colors.white.withValues(alpha: accepted ? 1 : 0.6), width: 1.5),
      ),
      child: AnimatedOpacity(
        duration: context.motion(PrismDurations.fast),
        opacity: accepted ? 1 : 0,
        child: const Icon(Icons.check_rounded, size: 18, color: Colors.black),
      ),
    );
  }
}
