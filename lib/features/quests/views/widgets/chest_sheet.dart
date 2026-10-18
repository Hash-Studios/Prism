import 'dart:math' as math;

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/quests/views/widgets/chest_art.dart';
import 'package:Prism/features/spin_wheel/views/widgets/coin_burst.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
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

/// The reward sheet for an opened chest: the chest bursts open, then the coins count up.
class ChestSheet extends StatefulWidget {
  const ChestSheet({super.key, required this.result});

  final ChestResult result;

  @override
  State<ChestSheet> createState() => _ChestSheetState();
}

class _ChestSheetState extends State<ChestSheet> with SingleTickerProviderStateMixin {
  static const double _chestSize = 176;
  static const double _shakeAngle = 5 * math.pi / 180;
  static const double _shakeScale = 0.04;

  static const double _burstAt = 0.22;
  static const Interval _lidOpen = Interval(_burstAt, 0.4, curve: PrismCurves.pop);
  static const Interval _glowUp = Interval(_burstAt, 0.4, curve: PrismCurves.enter);
  static const Interval _coinsFly = Interval(0.3, 0.85);
  static const Interval _amountIn = Interval(0.35, 0.55, curve: PrismCurves.enter);
  static const Interval _countUp = Interval(0.35, 0.8, curve: PrismCurves.enter);
  static const Interval _doubledPop = Interval(0.75, 0.9, curve: PrismCurves.pop);
  static const Interval _foundIn = Interval(0.85, 1, curve: PrismCurves.enter);

  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final Animation<double> _burst = _c.drive(CurveTween(curve: _coinsFly));
  bool _started = false;
  bool _buzzed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) {
      _c.value = 1;
      return;
    }
    _c.addListener(_buzzAtBurst);
    _c.forward();
  }

  void _buzzAtBurst() {
    if (_buzzed || _c.value < _burstAt) return;
    _buzzed = true;
    PrismHaptics.success();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _stage() {
    final double t = _c.value;
    final double shake = (t / _burstAt).clamp(0.0, 1.0);
    final double settle = _glowUp.transform(t);
    final double angle = t < _burstAt ? math.sin(shake * 6 * math.pi) * (0.35 + 0.65 * shake) * _shakeAngle : 0;
    final double scale = 1 + _shakeScale * (t < _burstAt ? shake : 1 - settle);
    return SizedBox(
      height: _chestSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.bottomCenter,
              child: ChestArt(size: _chestSize, lid: _lidOpen.transform(t), glow: settle),
            ),
          ),
          if (!context.reduceMotion) CoinBurst(animation: _burst, radius: _chestSize * 0.7),
        ],
      ),
    );
  }

  Widget _amount(BuildContext context) {
    final double t = _c.value;
    final double rise = _amountIn.transform(t);
    final double pop = _doubledPop.transform(t);
    return Opacity(
      opacity: rise,
      child: Transform.translate(
        offset: Offset(0, PrismSpace.md * (1 - rise)),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const PrismCoinIcon(size: 48),
                const SizedBox(width: PrismSpace.sm),
                Text(
                  '+${(widget.result.coins * _countUp.transform(t)).round()}',
                  style: PrismTextStyles.numeral(context, 56),
                ),
                if (widget.result.doubled) ...<Widget>[
                  const SizedBox(width: PrismSpace.sm),
                  Opacity(
                    opacity: pop.clamp(0.0, 1.0),
                    child: Transform.scale(scale: 0.6 + 0.4 * pop, child: const _DoubledTag()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _stage(),
            _amount(context),
            if (itemId != null) ...<Widget>[
              const SizedBox(height: PrismSpace.md),
              Opacity(
                opacity: _foundIn.transform(_c.value),
                child: Text(
                  'You also found ${cosmeticName(itemId)}',
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.rowTitle(context),
                ),
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
      ),
    );
  }
}

class _DoubledTag extends StatelessWidget {
  const _DoubledTag();

  @override
  Widget build(BuildContext context) {
    final WheelGold gold = WheelGold();
    return Transform.rotate(
      angle: -0.1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xxs),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[gold.light, gold.deep],
          ),
          borderRadius: BorderRadius.circular(PrismRadius.sm),
          border: Border.all(color: gold.ink, width: 2),
        ),
        child: Text(
          '\u00d72',
          style: PrismTextStyles.cardTitle(context).copyWith(color: gold.ink, fontSize: 22, height: 1),
        ),
      ),
    );
  }
}
