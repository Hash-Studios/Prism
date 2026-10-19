import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_preview.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:Prism/features/spin_wheel/views/widgets/count_up.dart';
import 'package:Prism/features/spin_wheel/views/widgets/spin_button.dart';
import 'package:Prism/l10n/l10n.dart';
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

  String _headlineLabel(AppLocalizations l10n) {
    final String? id = win.itemId;
    if (prize is CosmeticPrize && id != null) {
      final ShopItem? item = _item;
      return item == null
          ? l10n.economyWonUnknownCosmetic
          : l10n.economyWonCosmetic(_kind(l10n, item.kind), shopItemName(item, l10n));
    }
    if (prize is XpPrize) return l10n.economyWonXp(win.xp);
    return l10n.economyWonCoins(win.coins);
  }

  String _caption(AppLocalizations l10n) {
    if (prize is CosmeticPrize) {
      return win.itemId == null ? l10n.economyChestOwnCosmeticCoins : l10n.economyAddedToCollection;
    }
    if (prize is XpPrize) return l10n.economyAddedToXp;
    return jackpot ? l10n.economyJackpotAddedToBalance : l10n.economyAddedToBalance;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle caption = PrismTextStyles.caption(context).copyWith(color: ink.withValues(alpha: 0.78));
    final (String label, int? price, String? sub) = switch (action) {
      SpinAction.spin => (context.l10n.economySpinAgain, status.freeSpinAvailable ? null : status.nextCost, null),
      SpinAction.getCoins => (context.l10n.economyGetCoins, null, null),
      SpinAction.capped => (context.l10n.economyBackTomorrow, null, null),
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          label: _headlineLabel(context.l10n),
          excludeSemantics: true,
          child: _Headline(panel: this),
        ),
        const SizedBox(height: 2),
        Text(
          _caption(context.l10n),
          style: caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PrismSpace.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: SpinButton(
                compact: true,
                label: label,
                caption:
                    sub ??
                    (action == SpinAction.spin && status.freeSpinAvailable ? context.l10n.economyFreeSpin : null),
                price: price,
                semanticLabel: switch (action) {
                  SpinAction.spin =>
                    price == null ? context.l10n.economySpinAgainFree : context.l10n.economySpinAgainPrice(price),
                  SpinAction.getCoins => context.l10n.economyGetCoins,
                  SpinAction.capped => context.l10n.economyBackTomorrow,
                },
                onPressed: action == SpinAction.capped ? null : onSpinAgain,
              ),
            ),
            const SizedBox(width: PrismSpace.xs),
            PrismButton(
              label: context.l10n.actionDone,
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

String _kind(AppLocalizations l10n, ShopItemKind kind) => switch (kind) {
  ShopItemKind.theme => l10n.economyCosmeticTheme,
  ShopItemKind.appIcon => l10n.economyCosmeticAppIcon,
  ShopItemKind.frame => l10n.economyCosmeticFrame,
  ShopItemKind.nameGlow => l10n.economyCosmeticNameGlow,
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
          ? context.l10n.economyNewUnknownCosmetic
          : context.l10n.economyNewCosmetic(_kind(context.l10n, item.kind), shopItemName(item, context.l10n));
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
          CountUp(value: panel.win.xp, style: numeral),
          const SizedBox(width: PrismSpace.xs),
          Text(context.l10n.economyXpUnit, style: PrismTextStyles.sectionTitle(context).copyWith(color: ink)),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PrismCoinIcon(size: 34),
        const SizedBox(width: PrismSpace.xs),
        CountUp(value: panel.win.coins, style: numeral),
      ],
    );
  }
}
