import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class CoinGateOption<T> {
  const CoinGateOption({required this.label, required this.value, this.outlined = false});

  final String label;
  final T value;
  final bool outlined;
}

/// Label of the watch-ad option, with what the next ad really pays (more for the first ad of the day).
String watchAdOptionLabel(AppLocalizations l10n) =>
    l10n.economyWatchVideoRewardCoins(CoinsService.instance.adsRewardNow);

/// Bottom sheet for a coin-gated action. Pops with the chosen option's value.
Future<T?> showCoinGateSheet<T>(
  BuildContext context, {
  required String title,
  required int cost,
  required String Function(int missing) message,
  required List<CoinGateOption<T>> options,
}) {
  return showPrismSheet<T>(
    context,
    builder: (sheetContext) {
      final int missing = (cost - CoinsService.instance.balanceNotifier.value).clamp(0, cost);
      return PrismSheetBody(
        title: title,
        message: message(missing),
        mood: missing > 0 ? GlintMood.worried : null,
        centered: true,
        actions: <Widget>[
          for (final (int index, CoinGateOption<T> option) in options.indexed)
            PrismButton(
              label: option.label,
              expand: true,
              variant: index == 0 && !option.outlined ? PrismButtonVariant.primary : PrismButtonVariant.tonal,
              onPressed: () => Navigator.of(sheetContext).pop(option.value),
            ),
          if (missing > 0)
            PrismButton(
              label: sheetContext.l10n.economyGetCoins,
              expand: true,
              variant: PrismButtonVariant.ghost,
              onPressed: () {
                final StackRouter router = context.router;
                Navigator.of(sheetContext).pop();
                router.pushPath('/rewards');
              },
            ),
        ],
        child: _CostAndBalance(cost: cost),
      );
    },
  );
}

/// The price of the action and the coins the user has now.
class _CostAndBalance extends StatelessWidget {
  const _CostAndBalance({required this.cost});

  final int cost;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (cost > 0)
          Semantics(
            label: context.l10n.economyCoins(cost),
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const PrismCoinIcon(size: 32),
                const SizedBox(width: PrismSpace.xs),
                Text(formatLocalizedNumber(cost, context.l10n), style: PrismTextStyles.numeral(context, 36)),
              ],
            ),
          ),
        const SizedBox(height: PrismSpace.xs),
        ValueListenableBuilder<int>(
          valueListenable: CoinsService.instance.balanceNotifier,
          builder: (context, balance, _) => Text(
            context.l10n.economyYouHaveCoins(balance),
            style: PrismTextStyles.caption(context),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
