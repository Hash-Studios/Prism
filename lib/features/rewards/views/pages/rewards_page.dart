import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/badges/views/widgets/rewards_badges_section.dart';
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
  const RewardsPage({super.key, this.showBack = true, this.scrollToEarn = false});

  final bool showBack;

  /// Scrolls to "Earn coins" once the page is laid out.
  final bool scrollToEarn;

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final GlobalKey _spendKey = GlobalKey();
  final GlobalKey _earnKey = GlobalKey();

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToEarn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealEarn());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The list builds rows lazily, so the Earn section may not exist yet. Scroll down a screen at a time until it does.
  Future<void> _revealEarn() async {
    for (int step = 0; step < 12 && mounted && _earnKey.currentContext == null; step++) {
      if (!_scroll.hasClients) return;
      final ScrollPosition position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent) return;
      _scroll.jumpTo((position.pixels + position.viewportDimension).clamp(0.0, position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted) _scrollTo(_earnKey);
  }

  void _scrollTo(GlobalKey key) {
    final BuildContext? target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target, duration: context.motion(PrismDurations.slow), curve: PrismCurves.move);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    // Coin callables need auth; guests (iOS browse without an account) sign in first.
    if (!app_state.prismUser.loggedIn) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          automaticallyImplyLeading: widget.showBack,
          title: const Text('Rewards'),
        ),
        body: const SignInPrompt(feature: 'streaks'),
      );
    }
    const SizedBox gap = SizedBox(height: 12);
    const EdgeInsets pad = EdgeInsets.symmetric(horizontal: 20);
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scroll,
          slivers: <Widget>[
            SliverToBoxAdapter(child: _Header(showBack: widget.showBack)),
            SliverPadding(
              padding: pad,
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
                  const RewardsBadgesSection(),
                  const RewardsCollectionSection(),
                  const RewardsActivitySection(),
                  // Clear the floating bottom nav.
                  SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom + 80),
                ],
              ),
            ),
          ],
        ),
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

class _Header extends StatelessWidget {
  const _Header({required this.showBack});

  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(showBack ? 8 : 20, 8, 20, 12),
      child: SizedBox(
        height: 44,
        child: Row(
          children: <Widget>[
            if (showBack)
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.router.maybePop(),
              ),
            Expanded(
              child: Semantics(header: true, child: Text('Rewards', style: PrismTextStyles.screenTitle(context))),
            ),
            ValueListenableBuilder<int>(
              valueListenable: CoinsService.instance.balanceNotifier,
              builder: (context, balance, _) => Semantics(
                label: '$balance Prism coins',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const PrismCoinIcon(size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '$balance',
                        style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
