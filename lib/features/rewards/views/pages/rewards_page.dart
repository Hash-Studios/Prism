import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/core/widgets/prism/prism_page.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/rewards/views/widgets/balance_card.dart';
import 'package:Prism/features/rewards/views/widgets/freeze_card.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_activity_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_collection_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_earn_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_hero.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_spend_section.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Streak, freezes and coins in one page. It is the Rewards tab, and a pushed route with a back button.
@RoutePage()
class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key, this.showBack = true});

  final bool showBack;

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final GlobalKey _spendKey = GlobalKey();
  final GlobalKey _earnKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final BuildContext? target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target, duration: context.motion(PrismDurations.slow), curve: PrismCurves.move);
  }

  void _back() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    // Coin callables need auth; guests (iOS browse without an account) sign in first.
    if (!app_state.prismUser.loggedIn) {
      return PrismPage(
        title: 'Rewards',
        showBack: widget.showBack,
        onBack: _back,
        body: const SignInPrompt(feature: 'rewards'),
      );
    }
    const SizedBox gap = SizedBox(height: PrismSpace.sm);
    final double bottom = widget.showBack
        ? PrismSpace.xxl + MediaQuery.paddingOf(context).bottom
        : PrismSpace.bottomBarClearance;
    return PrismPage(
      title: 'Rewards',
      showBack: widget.showBack,
      onBack: _back,
      actions: <Widget>[
        ValueListenableBuilder<int>(
          valueListenable: CoinsService.instance.balanceNotifier,
          builder: (context, balance, _) => CoinBalancePill(balance: balance),
        ),
        const SizedBox(width: PrismSpace.xs),
      ],
      body: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, bottom),
            sliver: SliverList.list(
              children: <Widget>[
                const RewardsHero(),
                gap,
                FreezeCard(onEarnCoins: () => _scrollTo(_earnKey)),
                gap,
                BalanceCard(onSeeUses: () => _scrollTo(_spendKey)),
                KeyedSubtree(
                  key: _spendKey,
                  child: RewardsSpendSection(
                    onStreakFreeze: () => buyStreakFreezeFlow(context, onEarnCoins: () => _scrollTo(_earnKey)),
                  ),
                ),
                KeyedSubtree(key: _earnKey, child: const RewardsEarnSection()),
                const RewardsCollectionSection(),
                const RewardsActivitySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Rewards tab body. Kept apart from [RewardsPage] so the tab and the pushed route have distinct routes.
@RoutePage()
class RewardsTabPage extends StatelessWidget {
  const RewardsTabPage({super.key});

  @override
  Widget build(BuildContext context) => const RewardsPage(showBack: false);
}
