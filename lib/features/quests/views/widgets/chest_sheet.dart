import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:flutter/material.dart';

/// Shows the result of an opened chest. Resolves true when the user asks to see the cosmetic in the Shop.
Future<bool> showChestSheet(BuildContext context, ChestResult result) async {
  final bool? openShop = await showPrismSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => ChestSheet(result: result),
  );
  return openShop ?? false;
}

/// The chest reward: a coin that pops in, the amount counting up, the odds, and a cosmetic if the chest held one.
class ChestSheet extends StatefulWidget {
  const ChestSheet({super.key, required this.result});

  final ChestResult result;

  @override
  State<ChestSheet> createState() => _ChestSheetState();
}

class _ChestSheetState extends State<ChestSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: PrismDurations.slow * 2);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) {
      _c.value = 1;
      return;
    }
    PrismHaptics.success();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChestResult r = widget.result;
    final String? itemId = r.itemId;
    final int cosmeticPercent = (EconomyConfig.current.award.questChestCosmeticChance * 100).round();
    final TextStyle caption = PrismTextStyles.caption(context);
    return PrismSheetBody(
      centered: true,
      scrollable: true,
      title: 'Chest opened',
      message: r.doubled ? 'Your bonus quest doubled it.' : 'Do the bonus quest before you open it to double it.',
      actions: <Widget>[
        if (itemId != null)
          PrismButton(
            label: 'See it in the Shop',
            expand: true,
            variant: PrismButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        PrismButton(
          label: 'Nice',
          expand: true,
          variant: itemId == null ? PrismButtonVariant.primary : PrismButtonVariant.tonal,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final double pop = const Interval(0, 0.5, curve: PrismCurves.pop).transform(_c.value);
              final double count = const Interval(0.15, 0.75, curve: PrismCurves.enter).transform(_c.value);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Transform.scale(scale: 0.6 + 0.4 * pop, child: const PrismCoinIcon(size: 48)),
                  const SizedBox(width: PrismSpace.sm),
                  Text('+${(r.coins * count).round()}', style: PrismTextStyles.numeral(context, 56)),
                ],
              );
            },
          ),
          if (itemId != null) ...<Widget>[
            const SizedBox(height: PrismSpace.md),
            Text(
              'You also found ${cosmeticName(itemId)}',
              textAlign: TextAlign.center,
              style: PrismTextStyles.rowTitle(context),
            ),
          ],
          const SizedBox(height: PrismSpace.md),
          Text(
            'A chest pays ${CoinPolicy.questChestMin} to ${CoinPolicy.questChestMax} coins, with a $cosmeticPercent% '
            'chance of a cosmetic. The bonus quest doubles the coins.',
            textAlign: TextAlign.center,
            style: caption,
          ),
        ],
      ),
    );
  }
}
