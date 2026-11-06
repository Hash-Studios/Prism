import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Own-profile completion as one row: a ring, the title and coin reward, the percent and a chevron. It sits inside the
/// XP card under a hairline, so the gallery stays near the top. Tapping it opens the editor, which lists what is
/// missing.
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
    SemanticsService.sendAnnouncement(View.of(context), context.l10n.accountOpeningProfileEditor, TextDirection.ltr);
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
    final String percent = '${formatLocalizedNumber(status.percent, context.l10n)}%';
    return Semantics(
      button: true,
      label: context.l10n.accountCompleteProfile,
      value: context.l10n.accountProfilePercentComplete(status.percent),
      hint: context.l10n.accountEarnProfileCompletionCoins(CoinPolicy.profileCompletion),
      excludeSemantics: true,
      onTap: _isLoading ? null : () => unawaited(_handleComplete()),
      // Transparent Material so the ripple draws over the card, not under it.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(PrismRadius.sm),
          onTap: _isLoading ? null : () => unawaited(_handleComplete()),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
            child: Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 28,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: status.progress),
                    duration: context.motion(PrismDurations.slow),
                    curve: PrismCurves.enter,
                    builder: (BuildContext context, double value, Widget? child) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                      color: cs.primary,
                      backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                const SizedBox(width: PrismSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(context.l10n.accountCompleteYourProfile, style: PrismTextStyles.rowTitle(context)),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          const PrismCoinIcon(size: 14),
                          const SizedBox(width: PrismSpace.xxs),
                          Expanded(
                            child: Text(
                              context.l10n.accountEarnProfileCompletionCoins(CoinPolicy.profileCompletion),
                              style: PrismTextStyles.caption(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PrismSpace.xs),
                Text(
                  percent,
                  style: PrismTextStyles.rowTitle(
                    context,
                  ).copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
                ),
                const SizedBox(width: PrismSpace.xxs),
                if (_isLoading)
                  const SizedBox.square(
                    dimension: 24,
                    child: Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
