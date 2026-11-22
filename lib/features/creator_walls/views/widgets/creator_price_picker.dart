import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Picks the coin price of one of the user's own walls. Free is 0. The server refuses any other price outside its list.
class CreatorPricePicker extends StatelessWidget {
  const CreatorPricePicker({super.key, required this.value, required this.onChanged, this.prices});

  /// The price in coins, or 0 for free.
  final int value;

  /// Called with the chosen price. Null disables the picker.
  final ValueChanged<int>? onChanged;

  /// The prices to offer. Defaults to the server list.
  final List<int>? prices;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ValueChanged<int>? change = onChanged;
    final List<int> options = prices ?? EconomyConfig.current.creatorWallPrices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.creatorWallPriceTitle, style: PrismTextStyles.cardTitle(context)),
        const SizedBox(height: PrismSpace.xxs),
        Text(l10n.creatorWallPriceHelp, style: PrismTextStyles.body(context)),
        const SizedBox(height: PrismSpace.sm),
        Wrap(
          spacing: PrismSpace.sm,
          runSpacing: PrismSpace.sm,
          children: <Widget>[
            Semantics(
              selected: value == 0,
              button: true,
              label: l10n.creatorWallPriceFree,
              excludeSemantics: true,
              onTap: change == null ? null : () => change(0),
              child: PrismChip(
                label: l10n.creatorWallPriceFree,
                selected: value == 0,
                // PrismChip plays the selection haptic itself.
                onTap: change == null ? null : () => change(0),
              ),
            ),
            for (final int price in options)
              Semantics(
                selected: value == price,
                button: true,
                label: l10n.creatorWallPriceOption(price),
                excludeSemantics: true,
                onTap: change == null ? null : () => change(price),
                child: PrismChip(
                  label: '$price',
                  leading: const PrismCoinIcon(size: 16),
                  selected: value == price,
                  onTap: change == null ? null : () => change(price),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
