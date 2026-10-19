import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The streak count and the next reward in a pill that opens Rewards.
class StreakPill extends StatelessWidget {
  const StreakPill({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!app_state.prismUser.loggedIn) {
      return const SizedBox.shrink();
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int streakDay = status.streakDay.clamp(0, 7);
        final bool active = status.active;
        final int nextDay = active ? (streakDay >= 7 ? 1 : streakDay + 1) : 1;
        final int nextReward = CoinPolicy.streakClaimRewardForDay(nextDay, isPro: app_state.prismUser.premium);
        final AppLocalizations l10n = context.l10n;
        final String nextLabel = compact
            ? '+${formatLocalizedNumber(nextReward, l10n)}'
            : l10n.coreStreakNext(nextReward);
        return StatPill(
          compact: compact,
          semanticLabel: l10n.coreStreakSemantics(status.count, nextReward),
          onTap: () {
            PrismHaptics.tap();
            context.router.push(RewardsRoute());
          },
          tint: active ? PrismColors.warning.withValues(alpha: 0.14) : null,
          borderColor: active ? PrismColors.warning.withValues(alpha: 0.6) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.local_fire_department_rounded,
                size: compact ? 16 : 18,
                color: active ? PrismColors.warning : cs.onSurfaceVariant,
              ),
              SizedBox(width: compact ? PrismSpace.xxs : 6),
              Text(formatLocalizedNumber(status.count, l10n), style: PrismTextStyles.rowTitle(context)),
              SizedBox(width: compact ? PrismSpace.xxs : PrismSpace.xs),
              Text(nextLabel, style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}
