import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum ProfileCompletenessNudgeAction { completeNow, notNow }

Future<ProfileCompletenessNudgeAction?> showProfileCompletenessNudgeSheet(
  BuildContext context, {
  required ProfileCompletenessStatus status,
}) {
  return showPrismSheet<ProfileCompletenessNudgeAction>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    barrierDismissible: false,
    swipeDismissible: false,
    builder: (context) => _ProfileCompletenessNudgeSheet(status: status),
  );
}

class _ProfileCompletenessNudgeSheet extends StatelessWidget {
  const _ProfileCompletenessNudgeSheet({required this.status});

  final ProfileCompletenessStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismSheetBody(
      mood: GlintMood.proud,
      centered: true,
      showHandle: false,
      showCloseButton: false,
      title: context.l10n.accountFinishYourProfile,
      message: context.l10n.accountProfileNudgeMessage(status.percent, CoinPolicy.profileCompletion),
      actions: <Widget>[
        PrismButton(
          label: context.l10n.accountCompleteProfile,
          expand: true,
          onPressed: () {
            Navigator.of(context).pop(ProfileCompletenessNudgeAction.completeNow);
          },
        ),
        PrismButton(
          label: context.l10n.accountLater,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(ProfileCompletenessNudgeAction.notNow),
        ),
      ],
      child: Column(
        children: <Widget>[
          for (final ProfileCompletenessStep step in status.missingSteps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.radio_button_unchecked_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: PrismSpace.xs),
                  Flexible(
                    child: Text(
                      profileCompletenessStepLabel(context.l10n, step),
                      style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
