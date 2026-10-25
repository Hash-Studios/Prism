import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/app_icon_channel.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:Prism/features/ads/views/widgets/coin_gate_sheet.dart';
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_preview.dart';
import 'package:Prism/features/shop/views/widgets/shop_labels.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the sheet for [item]. The sheet owns its [ShopBloc], so any screen can call this.
Future<void> showShopItemSheet(BuildContext context, ShopItem item) {
  return showPrismSheet<void>(
    context,
    builder: (_) => BlocProvider<ShopBloc>(
      create: (_) => getIt<ShopBloc>()..add(const ShopEvent.started()),
      child: ShopItemSheet(item: item),
    ),
  );
}

class ShopItemSheet extends StatefulWidget {
  const ShopItemSheet({super.key, required this.item});

  final ShopItem item;

  @override
  State<ShopItemSheet> createState() => _ShopItemSheetState();
}

class _ShopItemSheetState extends State<ShopItemSheet> {
  ShopItem get item => widget.item;

  Future<void> _watchAndBuy() async {
    final ShopBloc bloc = context.read<ShopBloc>();
    final bool credited = await CoinGate.forContext(
      context,
    ).watchAdForCoins(sourceTag: 'shop.item_sheet.ad', upsellSource: 'shop_item_sheet', isMounted: () => mounted);
    if (credited && mounted && bloc.state.balance >= shopPriceFor(item)) {
      bloc.add(ShopEvent.purchaseRequested(item.id));
    }
  }

  void _useTheme() {
    final String themeId = item.themeId ?? '';
    if (prismThemeById(prismLightThemes, themeId) != null) {
      context.setPrismLightTheme(themeId);
    } else {
      context.setPrismDarkTheme(themeId);
    }
    Navigator.of(context).pop();
  }

  Future<void> _useIcon() async {
    final bool changed = await AppIconChannel.setIcon(item == defaultAppIcon ? null : item.id);
    if (!mounted) return;
    if (changed) {
      toasts.success(context.l10n.economyShopIconEnabled(shopItemName(item, context.l10n)));
      Navigator.of(context).pop();
    } else {
      toasts.error(context.l10n.economyShopChangeIconFailed);
    }
  }

  void _equip({required bool equip}) =>
      context.read<ShopBloc>().add(ShopEvent.equipRequested(itemId: item.id, equip: equip));

  void _earnCoins() {
    final StackRouter router = context.router;
    Navigator.of(context).pop();
    router.pushPath('/rewards');
  }

  Future<void> _getPro() async {
    final BuildContext host = context;
    Navigator.of(host).pop();
    await PaywallOrchestrator.instance.presentOrRequireSignIn(
      host,
      placement: PaywallPlacement.mainUpsell,
      source: 'shop_item_sheet',
    );
  }

  String? _message(AppLocalizations l10n, ShopState state, ShopAvailability availability, bool owned, int missing) {
    if (owned) {
      return item.proOnly && item.slot != null && !state.premium ? l10n.economyShopWearingNeedsPro : null;
    }
    if (item.rankReward != null) {
      return availability == ShopAvailability.rankLocked
          ? l10n.economyShopEarnedAtLifetimeXp(shopRankName(item.rankReward!, l10n))
          : l10n.economyShopRankReachedSyncing;
    }
    return switch (availability) {
      ShopAvailability.soldOut => l10n.economyShopSoldOut,
      ShopAvailability.proOnly => l10n.economyShopProOnly,
      ShopAvailability.rankLocked => l10n.economyShopReachRankToBuy(shopRankName(item.requiredRank ?? '', l10n)),
      ShopAvailability.available when missing > 0 => l10n.economyShopCoinsShort(missing),
      ShopAvailability.available when item.founders => l10n.economyShopSaleUntil(
        shopUntilLabel(l10n) ?? l10n.economySoon,
      ),
      ShopAvailability.available => null,
    };
  }

  List<Widget> _actions(ShopState state, ShopAvailability availability, bool owned, int price) {
    final bool loading = state.loadingItemId == item.id;
    if (owned) {
      return switch (item.kind) {
        ShopItemKind.theme => <Widget>[
          PrismButton(label: context.l10n.economyShopUseTheme, expand: true, onPressed: _useTheme),
        ],
        ShopItemKind.appIcon => <Widget>[
          PrismButton(label: context.l10n.economyShopUseIcon, expand: true, onPressed: _useIcon),
        ],
        _ => <Widget>[
          if (state.isEquipped(item))
            PrismButton(
              label: context.l10n.economyShopUnequip,
              expand: true,
              variant: PrismButtonVariant.tonal,
              loading: loading,
              onPressed: () => _equip(equip: false),
            )
          else
            PrismButton(
              label: context.l10n.economyShopEquip,
              expand: true,
              loading: loading,
              onPressed: item.proOnly && !state.premium ? null : () => _equip(equip: true),
            ),
        ],
      };
    }
    if (item.rankReward != null) {
      return <Widget>[
        PrismButton(
          label: availability == ShopAvailability.rankLocked
              ? context.l10n.economyShopEarnXp
              : context.l10n.economyShopSyncReward,
          expand: true,
          variant: PrismButtonVariant.tonal,
          loading: loading,
          onPressed: availability == ShopAvailability.rankLocked
              ? _earnCoins
              : () => context.read<ShopBloc>().add(ShopEvent.purchaseRequested(item.id)),
        ),
      ];
    }
    return switch (availability) {
      ShopAvailability.soldOut => const <Widget>[],
      ShopAvailability.proOnly => <Widget>[
        PrismButton(label: context.l10n.economyGetPro, expand: true, onPressed: _getPro),
      ],
      ShopAvailability.rankLocked => <Widget>[
        PrismButton(
          label: context.l10n.economyEarnCoins,
          expand: true,
          variant: PrismButtonVariant.tonal,
          onPressed: _earnCoins,
        ),
      ],
      ShopAvailability.available when state.balance >= price => <Widget>[
        PrismButton(
          label: context.l10n.economyShopBuyFor(price),
          expand: true,
          loading: loading,
          onPressed: () => context.read<ShopBloc>().add(ShopEvent.purchaseRequested(item.id)),
        ),
      ],
      ShopAvailability.available => <Widget>[
        PrismButton(label: watchAdOptionLabel(context.l10n), expand: true, onPressed: _watchAndBuy),
        PrismButton(
          label: context.l10n.economyEarnCoins,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: _earnCoins,
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShopBloc, ShopState>(
      listenWhen: (ShopState previous, ShopState current) =>
          current.notice != null && !identical(previous.notice, current.notice),
      listener: (BuildContext context, ShopState state) {
        final ShopNotice notice = state.notice!;
        final String message = shopNoticeMessage(notice, context.l10n);
        notice.success ? toasts.success(message) : toasts.error(message);
      },
      builder: (BuildContext context, ShopState state) {
        final int price = shopPriceFor(item);
        final bool owned = state.isOwned(item);
        final ShopAvailability availability = state.availability(item);
        final int missing = (price - state.balance).clamp(0, price);
        return PrismSheetBody(
          title: shopItemName(item, context.l10n),
          message: _message(context.l10n, state, availability, owned, missing),
          centered: true,
          actions: _actions(state, availability, owned, price),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (item.kind == ShopItemKind.appIcon)
                ShopItemPreview(item: item, size: 168, sheen: true)
              else
                ShopItemPreview(item: item, size: 112),
              if (!owned && item.rankReward == null && availability != ShopAvailability.soldOut) ...<Widget>[
                const SizedBox(height: PrismSpace.md),
                Semantics(
                  label: context.l10n.economyCoins(price),
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const PrismCoinIcon(size: 22),
                      const SizedBox(width: PrismSpace.xs),
                      Text(formatLocalizedNumber(price, context.l10n), style: PrismTextStyles.numeral(context, 24)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

String shopNoticeMessage(ShopNotice notice, AppLocalizations l10n) {
  final ShopItem? item = shopItem(notice.itemId);
  final String name = item == null ? l10n.economyUnknownCosmetic : shopItemName(item, l10n);
  final String rank = shopRankName(notice.rankId ?? '', l10n);
  return switch (notice.kind) {
    ShopNoticeKind.rankRewardSynced => l10n.economyShopRankRewardSynced(name),
    ShopNoticeKind.purchased => l10n.economyShopPurchased(name),
    ShopNoticeKind.alreadyOwned => l10n.economyShopAlreadyOwned,
    ShopNoticeKind.proOnly => l10n.economyShopProOnly,
    ShopNoticeKind.rankLocked => l10n.economyShopRankLocked(rank),
    ShopNoticeKind.soldOut => l10n.economyShopSoldOut,
    ShopNoticeKind.insufficient => l10n.economyShopNeedMoreCoins,
    ShopNoticeKind.purchaseFailed => l10n.economyShopPurchaseFailed,
    ShopNoticeKind.equipped => l10n.economyShopEquipped(name),
    ShopNoticeKind.unequipped => l10n.economyShopUnequipped(name),
    ShopNoticeKind.equipFailed => l10n.economyShopEquipFailed,
  };
}
