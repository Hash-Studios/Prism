import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The page's main action. It says why it is off, and sends the user to Rewards when they are short of coins.
class AiGenerateBar extends StatelessWidget {
  const AiGenerateBar({
    super.key,
    required this.cost,
    required this.balance,
    required this.hasPrompt,
    required this.loading,
    required this.onGenerate,
    required this.onGetCoins,
  });

  final int cost;
  final int balance;
  final bool hasPrompt;
  final bool loading;

  final VoidCallback onGenerate;
  final VoidCallback onGetCoins;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool hasCoins = balance >= cost;
    final String? reason = loading
        ? null
        : !hasCoins
        ? l10n.economyAiCoinsNeeded(cost, balance)
        : !hasPrompt
        ? l10n.economyAiDescribeScene
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(bottom: PrismSpace.xs),
            child: Text(reason, textAlign: TextAlign.center, style: PrismTextStyles.caption(context)),
          ),
        PrismButton(
          label: hasCoins ? l10n.economyAiGenerate : l10n.economyEarnCoins,
          expand: true,
          loading: loading,
          trailing: hasCoins
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const PrismCoinIcon(size: 18),
                    const SizedBox(width: PrismSpace.xxs),
                    Text(formatLocalizedNumber(cost, l10n)),
                  ],
                )
              : null,
          onPressed: !hasCoins ? onGetCoins : (hasPrompt ? onGenerate : null),
        ),
      ],
    );
  }
}
