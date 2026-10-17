import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_sheet.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

String _kindLabel(ShopItemKind kind) => switch (kind) {
  ShopItemKind.theme => 'Themes',
  ShopItemKind.appIcon => 'Icons',
  ShopItemKind.frame => 'Frames',
  ShopItemKind.nameGlow => 'Name glows',
};

@RoutePage()
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ShopBloc>(
      create: (_) => getIt<ShopBloc>()..add(const ShopEvent.started()),
      child: const _ShopView(),
    );
  }
}

class _ShopView extends StatelessWidget {
  const _ShopView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShopBloc, ShopState>(
      builder: (BuildContext context, ShopState state) {
        final List<ShopItem> items = state.items;
        final DateTime now = DateTime.now();
        return PrismPage(
          title: 'Shop',
          actions: <Widget>[
            ValueListenableBuilder<int>(
              valueListenable: CoinsService.instance.balanceNotifier,
              builder: (BuildContext context, int balance, _) => CoinBalancePill(balance: balance),
            ),
            const SizedBox(width: PrismSpace.xs),
          ],
          body: CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.md),
                sliver: SliverToBoxAdapter(
                  child: PrismSegmented<ShopItemKind>(
                    values: ShopItemKind.values,
                    selected: state.kind,
                    labelOf: _kindLabel,
                    onChanged: (ShopItemKind kind) => context.read<ShopBloc>().add(ShopEvent.kindChanged(kind)),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  PrismSpace.page,
                  0,
                  PrismSpace.page,
                  PrismSpace.xxl + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: PrismSpace.sm,
                    crossAxisSpacing: PrismSpace.sm,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ShopItem item = items[index];
                    return ShopItemTile(
                      item: item,
                      owned: state.isOwned(item),
                      equipped: state.isEquipped(item),
                      availability: state.availability(item, now: now),
                      onTap: () => showShopItemSheet(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
