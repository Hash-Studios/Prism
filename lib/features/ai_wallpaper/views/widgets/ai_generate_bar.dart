import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
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
    required this.prominent,
    required this.onGenerate,
    required this.onGetCoins,
  });

  final int cost;
  final int balance;
  final bool hasPrompt;
  final bool loading;

  /// False when a result is on screen: its Save button is the accent action then.
  final bool prominent;
  final VoidCallback onGenerate;
  final VoidCallback onGetCoins;

  @override
  Widget build(BuildContext context) {
    final bool hasCoins = balance >= cost;
    final String? reason = loading
        ? null
        : !hasCoins
        ? 'You need $cost coins. You have $balance.'
        : !hasPrompt
        ? 'Describe a scene to generate.'
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
          label: hasCoins ? 'Generate' : 'Get coins',
          expand: true,
          loading: loading,
          variant: prominent ? PrismButtonVariant.primary : PrismButtonVariant.tonal,
          trailing: hasCoins
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const PrismCoinIcon(size: 18),
                    const SizedBox(width: PrismSpace.xxs),
                    Text('$cost'),
                  ],
                )
              : null,
          onPressed: !hasCoins ? onGetCoins : (hasPrompt ? onGenerate : null),
        ),
      ],
    );
  }
}
