import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/rewards/domain/rank_progress.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_preview.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
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
              Expanded(child: Text(context.l10n.economyYourXp, style: PrismTextStyles.eyebrow(context))),
              IconButton(
                tooltip: context.l10n.economyRankRewardsHelp,
                style: IconButton.styleFrom(minimumSize: const Size.square(48), visualDensity: VisualDensity.standard),
                onPressed: () => showXpExplanation(context, progress: progress, onOpenShop: onOpenShop),
                icon: const Icon(Icons.info_outline_rounded, size: 20),
              ),
            ],
          ),
          Text(rankTitle(progress.rank.id, context.l10n), style: PrismTextStyles.cardTitle(context)),
          const SizedBox(height: PrismSpace.xxs),
          Text(
            context.l10n.economyLifetimeXp(groupedXp(progress.xp, context.l10n)),
            style: PrismTextStyles.body(context),
          ),
          const SizedBox(height: PrismSpace.md),
          Semantics(
            label: context.l10n.economyRankProgressSemantics(rankTitle(progress.rank.id, context.l10n)),
            value: next == null
                ? context.l10n.economyHighestRankReached(rankTitle(progress.rank.id, context.l10n))
                : context.l10n.economyXpToRank(
                    groupedXp(progress.remainingXp, context.l10n),
                    rankTitle(next.id, context.l10n),
                  ),
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
            next == null
                ? context.l10n.economyHighestRankReachedShort
                : context.l10n.economyXpToRank(
                    groupedXp(progress.remainingXp, context.l10n),
                    rankTitle(next.id, context.l10n),
                  ),
            style: PrismTextStyles.caption(context),
          ),
          const SizedBox(height: PrismSpace.md),
          Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
          const SizedBox(height: PrismSpace.md),
          if (reward != null)
            _RewardSummary(reward: reward)
          else ...<Widget>[
            Text(
              progress.rewards.isEmpty
                  ? context.l10n.economyRankGrowsWithXp
                  : context.l10n.economyAllRankRewardsCollected,
              style: PrismTextStyles.rowTitle(context),
            ),
            const SizedBox(height: PrismSpace.xxs),
            Text(context.l10n.economyLifetimeXpNeverResets, style: PrismTextStyles.caption(context)),
          ],
          if (onUseReward != null && ownedReward != null) ...<Widget>[
            const SizedBox(height: PrismSpace.xs),
            TextButton(
              onPressed: () => onUseReward!(ownedReward.item),
              child: Text(context.l10n.economyUseReward(ownedReward.name(context.l10n))),
            ),
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
          reward.earned
              ? context.l10n.economyRewardEarned(reward.name(context.l10n))
              : context.l10n.economyNextReward(reward.name(context.l10n)),
          style: PrismTextStyles.rowTitle(context),
        ),
        const SizedBox(height: PrismSpace.xxs),
        Text(
          reward.earned
              ? context.l10n.economyRankRewardSyncing
              : context.l10n.economyRankRewardAtRank(
                  rankTitle(reward.rank.id, context.l10n),
                  groupedXp(reward.rank.min, context.l10n),
                ),
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
      final String title = rankTitle(config.rankFor(xp).id, context.l10n);
      return TextButton(
        onPressed: () => showXpExplanation(context),
        child: Semantics(
          label: context.l10n.economyRankInfoSemantics(title),
          excludeSemantics: true,
          child: Text(title),
        ),
      );
    },
  );
}

Future<void> showXpExplanation(BuildContext context, {RankProgress? progress, VoidCallback? onOpenShop}) =>
    showPrismSheet<void>(
      context,
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
    return PrismSheetBody(
      title: context.l10n.economyXpRanksRewards,
      actions: <Widget>[
        if (onOpenShop != null)
          PrismButton(
            label: context.l10n.economyOpenShop,
            expand: true,
            onPressed: () {
              Navigator.of(context).pop();
              onOpenShop!();
            },
          ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Explanation(
            title: context.l10n.economyEarnXpAsYouGo,
            text: context.l10n.economyXpActivityDetails(
              activities.dailyStreak,
              activities.streakWeek,
              activities.questChest,
              activities.firstWallpaperUpload,
              activities.profileCompletion,
              awards.questXp,
              awards.weeklyQuestXp,
            ),
          ),
          _Explanation(title: context.l10n.economySameActivitySameXp, text: context.l10n.economySameActivityXpDetails),
          _Explanation(
            title: context.l10n.economyLifetimePermanentRewards,
            text: context.l10n.economyLifetimePermanentDetails,
          ),
          for (final RankRewardProgress reward in milestones.rewards)
            Padding(
              padding: const EdgeInsets.only(bottom: PrismSpace.sm),
              child: Text(
                context.l10n.economyRankRewardMilestone(
                  rankTitle(reward.rank.id, context.l10n),
                  groupedXp(reward.rank.min, context.l10n),
                  reward.name(context.l10n),
                ),
                style: PrismTextStyles.body(context),
              ),
            ),
          const SizedBox(height: PrismSpace.sm),
          _Explanation(
            title: context.l10n.economyFreshLeaderboardWeekly,
            text: context.l10n.economyFreshLeaderboardDetails,
          ),
          _Explanation(title: context.l10n.economyCoinsAreYoursToSpend, text: context.l10n.economyCoinsSpendingDetails),
        ],
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
