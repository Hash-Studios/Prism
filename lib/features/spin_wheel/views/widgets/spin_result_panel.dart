import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_preview.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:Prism/features/spin_wheel/views/widgets/spin_button.dart';
import 'package:flutter/material.dart';

/// What a landed spin paid, as the plinth shows it: the prize, a line under it and the next move.
class SpinResultPanel extends StatelessWidget {
  const SpinResultPanel({
    super.key,
    required this.win,
    required this.prize,
    required this.jackpot,
    required this.status,
    required this.action,
    required this.ink,
    required this.onSpinAgain,
    required this.onDone,
  });

  final WheelWin win;

  /// The slice the wheel landed on.
  final WheelPrize prize;
  final bool jackpot;
  final SpinWheelStatus status;

  /// What "Spin again" does now.
  final SpinAction action;

  /// Text colour on the plinth.
  final Color ink;
  final VoidCallback onSpinAgain;
  final VoidCallback onDone;

  /// The item the cosmetic slice paid, or null.
  ShopItem? get _item {
    final String? id = win.itemId;
    return id == null ? null : shopItem(id);
  }

  String get _headlineLabel {
    final String? id = win.itemId;
    if (prize is CosmeticPrize && id != null) {
      final ShopItem? item = _item;
      return item == null ? 'You won ${cosmeticName(id)}' : 'You won a new ${_kind(item.kind)}: ${item.name}';
    }
    if (prize is XpPrize) return 'You won ${win.xp} XP';
    return 'You won ${win.coins} coins';
  }

  String get _caption {
    if (prize is CosmeticPrize) {
      return win.itemId == null ? 'You own every cosmetic, so it pays coins' : 'Added to your collection';
    }
    if (prize is XpPrize) return 'Added to your XP';
    return jackpot ? 'Jackpot. Added to your balance' : 'Added to your balance';
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle caption = PrismTextStyles.caption(context).copyWith(color: ink.withValues(alpha: 0.78));
    final (String label, int? price, String? sub) = switch (action) {
      SpinAction.spin => ('Spin again', status.freeSpinAvailable ? null : status.nextCost, null),
      SpinAction.getCoins => ('Get coins', null, null),
      SpinAction.capped => ('Back tomorrow', null, null),
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          label: _headlineLabel,
          excludeSemantics: true,
          child: _Headline(panel: this),
        ),
        const SizedBox(height: 2),
        Text(_caption, style: caption, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        const SizedBox(height: PrismSpace.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: SpinButton(
                compact: true,
                label: label,
                caption: sub ?? (action == SpinAction.spin && status.freeSpinAvailable ? 'Free' : null),
                price: price,
                semanticLabel: switch (action) {
                  SpinAction.spin => price == null ? 'Spin again, free spin' : 'Spin again, $price coins',
                  SpinAction.getCoins => 'Get coins',
                  SpinAction.capped => 'Back tomorrow',
                },
                onPressed: action == SpinAction.capped ? null : onSpinAgain,
              ),
            ),
            const SizedBox(width: PrismSpace.xs),
            PrismButton(
              label: 'Done',
              variant: PrismButtonVariant.ghost,
              size: PrismButtonSize.compact,
              onPressed: onDone,
            ),
          ],
        ),
      ],
    );
  }
}

String _kind(ShopItemKind kind) => switch (kind) {
  ShopItemKind.theme => 'theme',
  ShopItemKind.appIcon => 'app icon',
  ShopItemKind.frame => 'frame',
  ShopItemKind.nameGlow => 'name glow',
};

class _Headline extends StatelessWidget {
  const _Headline({required this.panel});

  final SpinResultPanel panel;

  @override
  Widget build(BuildContext context) {
    final WheelPrize prize = panel.prize;
    final Color ink = panel.ink;
    final TextStyle numeral = PrismTextStyles.numeral(context, 38).copyWith(color: ink, fontWeight: FontWeight.w700);
    if (prize is CosmeticPrize && panel.win.itemId != null) {
      final ShopItem? item = panel._item;
      final String text = item == null
          ? 'New cosmetic: ${cosmeticName(panel.win.itemId!)}'
          : 'New ${_kind(item.kind)}: ${item.name}';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (item != null) ...<Widget>[ShopItemPreview(item: item, size: 40), const SizedBox(width: PrismSpace.sm)],
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PrismTextStyles.sectionTitle(context).copyWith(color: ink, height: 1.1),
            ),
          ),
        ],
      );
    }
    if (prize is XpPrize) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          _CountUp(value: panel.win.xp, style: numeral),
          const SizedBox(width: PrismSpace.xs),
          Text('XP', style: PrismTextStyles.sectionTitle(context).copyWith(color: ink)),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PrismCoinIcon(size: 34),
        const SizedBox(width: PrismSpace.xs),
        _CountUp(value: panel.win.coins, style: numeral),
      ],
    );
  }
}

/// "+N" counting up from 0. Under reduced motion it shows the number at once.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: context.reduceMotion ? 1 : 0, end: 1),
      duration: context.motion(PrismDurations.slow * 2),
      curve: PrismCurves.enter,
      builder: (BuildContext context, double t, Widget? _) => Text('+${(value * t).round()}', style: style),
    );
  }
}
