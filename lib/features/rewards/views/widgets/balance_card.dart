import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The coin balance with a link to what the coins buy.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.onSeeUses});

  /// Scrolls to the spend section.
  final VoidCallback onSeeUses;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color muted = cs.onSurface.withValues(alpha: 0.55);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ValueListenableBuilder<int>(
              valueListenable: CoinsService.instance.balanceNotifier,
              builder: (context, balance, _) => Semantics(
                label: '$balance Prism coins',
                excludeSemantics: true,
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    const PrismCoinIcon(size: 36),
                    Text('$balance', style: PrismTextStyles.numeral(context, 40).copyWith(letterSpacing: -0.4)),
                    Text('coins', style: PrismTextStyles.body(context)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
            PressScale(
              scale: 0.98,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSeeUses,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(child: Text('What you can do with them', style: PrismTextStyles.rowTitle(context))),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: cs.onSurface.withValues(alpha: 0.06)),
                        child: Icon(Icons.chevron_right_rounded, size: 20, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text('With Pro, downloads and filters are free. ', style: PrismTextStyles.caption(context)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => PaywallOrchestrator.instance.presentOrRequireSignIn(
                    context,
                    placement: PaywallPlacement.mainUpsell,
                    source: 'rewards_balance_card',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'See Pro',
                      style: PrismTextStyles.rowTitle(
                        context,
                      ).copyWith(decoration: TextDecoration.underline, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
