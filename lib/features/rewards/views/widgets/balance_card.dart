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
    final Color muted = cs.onSurface.withValues(alpha: 0.6);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
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
                child: Row(
                  children: <Widget>[
                    const PrismCoinIcon(size: 36),
                    const SizedBox(width: 14),
                    Text(
                      '$balance',
                      style: TextStyle(
                        fontFamily: PrismFonts.fraunces,
                        fontWeight: FontWeight.w600,
                        fontSize: 40,
                        height: 1,
                        letterSpacing: -0.4,
                        color: cs.onSurface,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('coins', style: theme.textTheme.bodyLarge?.copyWith(color: muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: cs.outlineVariant),
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
                      Text(
                        'What you can do with them',
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surfaceContainerHighest),
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
                Text(
                  'With Pro, downloads and filters are free. ',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface,
                        decoration: TextDecoration.underline,
                      ),
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
