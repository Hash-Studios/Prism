import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The coin balance with a link to what the coins buy, and a Pro note for people who do not have Pro.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.onSeeUses});

  /// Scrolls to the spend section.
  final VoidCallback onSeeUses;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ValueListenableBuilder<int>(
            valueListenable: CoinsService.instance.balanceNotifier,
            builder: (context, balance, _) => Semantics(
              label: '$balance Prism coins',
              excludeSemantics: true,
              child: Wrap(
                spacing: PrismSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const PrismCoinIcon(size: 36),
                  Text('$balance', style: PrismTextStyles.numeral(context, 40).copyWith(letterSpacing: -0.4)),
                  Text('coins', style: PrismTextStyles.body(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: PrismSpace.sm),
          Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
          PrismRow(
            title: 'What you can do with them',
            onTap: onSeeUses,
            padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
          ),
          if (!app_state.prismUser.premium)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('With Pro, downloads and filters are free.', style: PrismTextStyles.caption(context)),
                ),
                PrismButton(
                  label: 'See Pro',
                  variant: PrismButtonVariant.ghost,
                  size: PrismButtonSize.compact,
                  onPressed: () => PaywallOrchestrator.instance.presentOrRequireSignIn(
                    context,
                    placement: PaywallPlacement.mainUpsell,
                    source: 'rewards_balance_card',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
