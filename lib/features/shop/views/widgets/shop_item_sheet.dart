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
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the sheet for [item]. The sheet owns its [ShopBloc], so any screen can call this.
Future<void> showShopItemSheet(BuildContext context, ShopItem item) {
  return showPrismSheet<void>(
    context: context,
    isScrollControlled: true,
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
    final bool changed = await AppIconChannel.setIcon(item.id);
    if (!mounted) return;
    if (changed) {
      toasts.success('${item.name} icon is on');
      Navigator.of(context).pop();
    } else {
      toasts.error('Could not change the icon');
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

  String? _message(ShopState state, ShopAvailability availability, bool owned, int missing) {
    if (owned) {
      return item.proOnly && item.slot != null && !state.premium ? 'Wearing this needs Pro.' : null;
    }
    return switch (availability) {
      ShopAvailability.soldOut => 'This limited item is sold out.',
      ShopAvailability.proOnly => 'Only Pro members can buy this.',
      ShopAvailability.rankLocked => 'Reach ${shopRankName(item.minRank ?? '')} rank to buy this.',
      ShopAvailability.available when missing > 0 => 'You need $missing more coins.',
      ShopAvailability.available when item.founders => 'Limited. On sale until ${shopUntilLabel() ?? 'soon'}.',
      ShopAvailability.available => null,
    };
  }

  List<Widget> _actions(ShopState state, ShopAvailability availability, bool owned, int price) {
    final bool loading = state.loadingItemId == item.id;
    if (owned) {
      return switch (item.kind) {
        ShopItemKind.theme => <Widget>[PrismButton(label: 'Use theme', expand: true, onPressed: _useTheme)],
        ShopItemKind.appIcon => <Widget>[PrismButton(label: 'Use icon', expand: true, onPressed: _useIcon)],
        _ => <Widget>[
          if (state.isEquipped(item))
            PrismButton(
              label: 'Unequip',
              expand: true,
              variant: PrismButtonVariant.tonal,
              loading: loading,
              onPressed: () => _equip(equip: false),
            )
          else
            PrismButton(
              label: 'Equip',
              expand: true,
              loading: loading,
              onPressed: item.proOnly && !state.premium ? null : () => _equip(equip: true),
            ),
        ],
      };
    }
    return switch (availability) {
      ShopAvailability.soldOut => const <Widget>[],
      ShopAvailability.proOnly => <Widget>[PrismButton(label: 'Get Pro', expand: true, onPressed: _getPro)],
      ShopAvailability.rankLocked => <Widget>[
        PrismButton(label: 'Earn coins', expand: true, variant: PrismButtonVariant.tonal, onPressed: _earnCoins),
      ],
      ShopAvailability.available when state.balance >= price => <Widget>[
        PrismButton(
          label: 'Buy for $price',
          expand: true,
          loading: loading,
          onPressed: () => context.read<ShopBloc>().add(ShopEvent.purchaseRequested(item.id)),
        ),
      ],
      ShopAvailability.available => <Widget>[
        PrismButton(label: watchAdOptionLabel(), expand: true, onPressed: _watchAndBuy),
        PrismButton(label: 'Earn coins', expand: true, variant: PrismButtonVariant.ghost, onPressed: _earnCoins),
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
        notice.success ? toasts.success(notice.message) : toasts.error(notice.message);
      },
      builder: (BuildContext context, ShopState state) {
        final int price = shopPriceFor(item);
        final bool owned = state.isOwned(item);
        final ShopAvailability availability = state.availability(item);
        final int missing = (price - state.balance).clamp(0, price);
        return PrismSheetBody(
          title: item.name,
          message: _message(state, availability, owned, missing),
          centered: true,
          scrollable: true,
          actions: _actions(state, availability, owned, price),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (item.kind == ShopItemKind.appIcon)
                ShopItemPreview(item: item, size: 168, sheen: true)
              else
                ShopItemPreview(item: item, size: 112),
              if (!owned && availability != ShopAvailability.soldOut) ...<Widget>[
                const SizedBox(height: PrismSpace.md),
                Semantics(
                  label: '$price coins',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const PrismCoinIcon(size: 22),
                      const SizedBox(width: PrismSpace.xs),
                      Text('$price', style: PrismTextStyles.numeral(context, 24)),
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
