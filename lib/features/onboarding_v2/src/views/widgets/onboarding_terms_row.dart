import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/l10n/l10n.dart';
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
    final AppLocalizations l10n = context.l10n;
    const String termsMarker = '\u{e000}terms\u{e001}';
    const String privacyMarker = '\u{e000}privacy\u{e001}';
    final String agreement = l10n.accountTermsAgreementSemanticLabel(termsMarker, privacyMarker);
    final TextStyle linkStyle = text.copyWith(decoration: TextDecoration.underline, color: Colors.white);
    final List<InlineSpan> agreementSpans = <InlineSpan>[];
    int cursor = 0;
    while (cursor < agreement.length) {
      final int termsIndex = agreement.indexOf(termsMarker, cursor);
      final int privacyIndex = agreement.indexOf(privacyMarker, cursor);
      final bool isTerms = termsIndex >= 0 && (privacyIndex < 0 || termsIndex < privacyIndex);
      final int markerIndex = isTerms ? termsIndex : privacyIndex;
      if (markerIndex < 0) {
        agreementSpans.add(TextSpan(text: agreement.substring(cursor)));
        break;
      }
      if (markerIndex > cursor) {
        agreementSpans.add(TextSpan(text: agreement.substring(cursor, markerIndex)));
      }
      final String marker = isTerms ? termsMarker : privacyMarker;
      agreementSpans.add(
        TextSpan(
          text: isTerms ? l10n.accountTerms : l10n.accountPrivacyPolicy,
          style: linkStyle,
          recognizer: isTerms ? legalTap : privacyTap,
        ),
      );
      cursor = markerIndex + marker.length;
    }
    if (agreementSpans.isEmpty) {
      agreementSpans.add(TextSpan(text: agreement));
    }
    void toggle() {
      PrismHaptics.selection();
      onChanged(!accepted);
    }

    return Semantics(
      container: true,
      checked: accepted,
      label: context.l10n.accountTermsAgreementSemanticLabel(l10n.accountTerms, l10n.accountPrivacyPolicy),
      onTap: toggle,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: l10n.accountTerms): () => legalTap.onTap?.call(),
        CustomSemanticsAction(label: l10n.accountPrivacyPolicy): () => privacyTap.onTap?.call(),
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
                  child: Text.rich(TextSpan(style: text, children: agreementSpans)),
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
