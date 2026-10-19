import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

class StageTopBar extends StatelessWidget {
  const StageTopBar({super.key, required this.balance, required this.delta, required this.low, required this.onClose});

  static const double height = 56;

  final int balance;
  final int delta;
  final bool low;

  /// Null shows the close button disabled.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
        child: Row(
          children: <Widget>[
            PrismIconButton(
              icon: Icons.close_rounded,
              tooltip: context.l10n.actionClose,
              filled: true,
              onPressed: onClose,
            ),
            const Spacer(),
            CoinBalancePill(balance: balance, delta: delta, low: low),
            const SizedBox(width: PrismSpace.xs),
          ],
        ),
      ),
    );
  }
}
