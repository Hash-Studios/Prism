import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/rewards/domain/rank_progress.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_preview.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_sheet.dart';
import 'package:flutter/material.dart';

class RankProgressCard extends StatelessWidget {
  const RankProgressCard({super.key, this.onOpenShop});

  final VoidCallback? onOpenShop;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[
      CoinsService.instance.xpNotifier,
      CoinsService.instance.inventoryNotifier,
      EconomyConfig.notifier,
    ]),
    builder: (context, _) => XpProgressCard(
      progress: RankProgress(
        xp: CoinsService.instance.xpNotifier.value.xp,
        owned: CoinsService.instance.inventoryNotifier.value.owned,
        config: EconomyConfig.current,
      ),
      onOpenShop: onOpenShop,
      onUseReward: (ShopItem item) => showShopItemSheet(context, item),
    ),
  );
}

class XpProgressCard extends StatelessWidget {
  const XpProgressCard({super.key, required this.progress, this.onOpenShop, this.onUseReward});

  final RankProgress progress;
  final VoidCallback? onOpenShop;
  final ValueChanged<ShopItem>? onUseReward;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final RankDef? next = progress.nextRank;
    final RankRewardProgress? reward = progress.nextReward;
    final RankRewardProgress? ownedReward = progress.rewards
        .where((RankRewardProgress reward) => reward.owned)
        .lastOrNull;
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('YOUR XP', style: PrismTextStyles.eyebrow(context))),
              IconButton(
                tooltip: 'How XP and rank rewards work',
                style: IconButton.styleFrom(minimumSize: const Size.square(48), visualDensity: VisualDensity.standard),
                onPressed: () => showXpExplanation(context, progress: progress, onOpenShop: onOpenShop),
                icon: const Icon(Icons.info_outline_rounded, size: 20),
              ),
            ],
          ),
          Text(rankTitle(progress.rank.id), style: PrismTextStyles.cardTitle(context)),
          const SizedBox(height: PrismSpace.xxs),
          Text('${groupedXp(progress.xp)} lifetime XP', style: PrismTextStyles.body(context)),
          const SizedBox(height: PrismSpace.md),
          Semantics(
            label: '${rankTitle(progress.rank.id)} rank progress',
            value: next == null
                ? 'Highest rank reached: ${rankTitle(progress.rank.id)}'
                : '${groupedXp(progress.remainingXp)} XP to ${rankTitle(next.id)}',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PrismRadius.pill),
              child: LinearProgressIndicator(
                value: progress.rank.progress,
                minHeight: 5,
                color: cs.primary,
                backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          const SizedBox(height: PrismSpace.xs),
          Text(
            next == null ? 'Highest rank reached' : '${groupedXp(progress.remainingXp)} XP to ${rankTitle(next.id)}',
            style: PrismTextStyles.caption(context),
          ),
          const SizedBox(height: PrismSpace.md),
          Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
          const SizedBox(height: PrismSpace.md),
          if (reward != null)
            _RewardSummary(reward: reward)
          else ...<Widget>[
            Text(
              progress.rewards.isEmpty ? 'Your rank grows with lifetime XP.' : 'All rank rewards collected',
              style: PrismTextStyles.rowTitle(context),
            ),
            const SizedBox(height: PrismSpace.xxs),
            Text('Lifetime XP never resets.', style: PrismTextStyles.caption(context)),
          ],
          if (onUseReward != null && ownedReward != null) ...<Widget>[
            const SizedBox(height: PrismSpace.xs),
            TextButton(onPressed: () => onUseReward!(ownedReward.item), child: Text('Use ${ownedReward.name}')),
          ],
        ],
      ),
    );
  }
}

class _RewardSummary extends StatelessWidget {
  const _RewardSummary({required this.reward});

  final RankRewardProgress reward;

  @override
  Widget build(BuildContext context) {
    final Widget preview = MediaQuery.withNoTextScaling(child: ShopItemPreview(item: reward.item, size: 48));
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          reward.earned ? '${reward.name} earned' : 'Next reward: ${reward.name}',
          style: PrismTextStyles.rowTitle(context),
        ),
        const SizedBox(height: PrismSpace.xxs),
        Text(
          reward.earned
              ? 'Syncing to your inventory. It is yours to keep.'
              : 'Yours automatically at ${rankTitle(reward.rank.id)} · ${groupedXp(reward.rank.min)} XP',
          style: PrismTextStyles.caption(context),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 260 || MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              preview,
              const SizedBox(height: PrismSpace.xs),
              copy,
            ],
          );
        }
        return Row(
          children: <Widget>[
            preview,
            const SizedBox(width: PrismSpace.sm),
            Expanded(child: copy),
          ],
        );
      },
    );
  }
}

/// Public profiles explain rank without showing another member's private inventory.
class RankInfoChip extends StatelessWidget {
  const RankInfoChip({super.key, required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<EconomyConfig>(
    valueListenable: EconomyConfig.notifier,
    builder: (context, config, _) {
      final String title = rankTitle(config.rankFor(xp).id);
      return TextButton(
        onPressed: () => showXpExplanation(context),
        child: Semantics(
          label: '$title rank. How XP and rank rewards work',
          excludeSemantics: true,
          child: Text(title),
        ),
      );
    },
  );
}

Future<void> showXpExplanation(BuildContext context, {RankProgress? progress, VoidCallback? onOpenShop}) =>
    showPrismSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => XpExplanationSheet(progress: progress, onOpenShop: onOpenShop),
    );

class XpExplanationSheet extends StatelessWidget {
  const XpExplanationSheet({super.key, this.progress, this.onOpenShop});

  final RankProgress? progress;
  final VoidCallback? onOpenShop;

  @override
  Widget build(BuildContext context) {
    final RankProgress milestones =
        progress ?? RankProgress(xp: 0, owned: const <String>{}, config: EconomyConfig.current);
    final EconomyAward awards = milestones.config.award;
    final EconomyXpActivities activities = milestones.config.xp.activities;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PrismSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text('XP, ranks & rewards', style: PrismTextStyles.sectionTitle(context))),
                IconButton(
                  tooltip: 'Close XP explanation',
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                    visualDensity: VisualDensity.standard,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: PrismSpace.md),
            _Explanation(
              title: 'Earn XP as you go',
              text:
                  'Daily streaks earn ${activities.dailyStreak} XP, plus ${activities.streakWeek} XP for completing a seven-day cycle. Quest chests earn ${activities.questChest} XP. Your first valid upload earns ${activities.firstWallpaperUpload} XP; profile completion earns ${activities.profileCompletion} XP. Daily quests award ${awards.questXp} XP each; the weekly quest awards ${awards.weeklyQuestXp} XP. Some badges and creator milestones also earn XP.',
            ),
            const _Explanation(
              title: 'The same activity earns the same XP',
              text:
                  'Ads, Pro spins, Pro daily bonuses, referrals and refunds earn no XP. Pro and coin multipliers do not increase XP. Coin rewards stay separate.',
            ),
            const _Explanation(
              title: 'Lifetime progress, permanent rewards',
              text:
                  'Lifetime XP sets your rank and never resets. Rank cosmetics arrive automatically in your inventory, cost no coins and stay yours. Choose when to equip them in the Shop.',
            ),
            for (final RankRewardProgress reward in milestones.rewards)
              Padding(
                padding: const EdgeInsets.only(bottom: PrismSpace.sm),
                child: Text(
                  '${rankTitle(reward.rank.id)} · ${groupedXp(reward.rank.min)} XP\n${reward.name}',
                  style: PrismTextStyles.body(context),
                ),
              ),
            const SizedBox(height: PrismSpace.sm),
            const _Explanation(
              title: 'A fresh leaderboard each week',
              text:
                  'The leaderboard uses weekly XP, which resets every Monday at 00:00 UTC. Your lifetime XP, rank and earned cosmetics stay.',
            ),
            const _Explanation(
              title: 'Coins are yours to spend',
              text:
                  'Coins pay for wallpapers, tools and Shop items. XP is progress, not a balance you spend. Spending coins never lowers your XP.',
            ),
            if (onOpenShop != null)
              PrismButton(
                label: 'Open Shop',
                expand: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenShop!();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: PrismSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: PrismTextStyles.rowTitle(context)),
        const SizedBox(height: PrismSpace.xxs),
        Text(text, style: PrismTextStyles.body(context)),
      ],
    ),
  );
}
