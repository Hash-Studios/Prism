import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Own-profile card: how complete the profile is, what is missing, and the way into the editor.
class ProfileCompletenessCard extends StatefulWidget {
  const ProfileCompletenessCard({super.key, required this.status, required this.onCompleteNow});

  final ProfileCompletenessStatus status;
  final Future<void> Function() onCompleteNow;

  @override
  State<ProfileCompletenessCard> createState() => _ProfileCompletenessCardState();
}

class _ProfileCompletenessCardState extends State<ProfileCompletenessCard> {
  bool _isLoading = false;

  Future<void> _handleComplete() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    SemanticsService.sendAnnouncement(View.of(context), 'Opening profile editor', TextDirection.ltr);
    try {
      await widget.onCompleteNow();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ProfileCompletenessStatus status = widget.status;
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(child: Text('Complete your profile', style: PrismTextStyles.cardTitle(context))),
              Semantics(
                label: 'Profile ${status.percent}% complete',
                excludeSemantics: true,
                child: Text('${status.percent}%', style: PrismTextStyles.numeral(context, 22)),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.xs),
          Row(
            children: <Widget>[
              const PrismCoinIcon(size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Earn ${CoinPolicy.profileCompletion} coins when you finish',
                  style: PrismTextStyles.caption(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: status.progress),
            duration: context.motion(PrismDurations.slow),
            curve: PrismCurves.enter,
            builder: (BuildContext context, double value, Widget? child) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              borderRadius: BorderRadius.circular(PrismRadius.pill),
              color: cs.primary,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: PrismSpace.sm),
          for (final ProfileCompletenessStep step in status.missingSteps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.radio_button_unchecked_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: PrismSpace.xs),
                  Expanded(child: Text(step.label, style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14))),
                ],
              ),
            ),
          const SizedBox(height: PrismSpace.xs),
          PrismButton(
            label: 'Complete profile',
            variant: PrismButtonVariant.tonal,
            size: PrismButtonSize.compact,
            loading: _isLoading,
            onPressed: () => unawaited(_handleComplete()),
          ),
        ],
      ),
    );
  }
}
