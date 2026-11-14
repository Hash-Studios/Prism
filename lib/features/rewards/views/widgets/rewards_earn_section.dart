import 'dart:async';

import 'package:Prism/core/coins/coin_events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/core/widgets/prism/prism_section.dart';
import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:Prism/features/promo_codes/domain/entities/promo_code.dart';
import 'package:Prism/features/promo_codes/views/redeem_code_sheet.dart';
import 'package:Prism/features/rewards/views/widgets/coin_event_banner.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// "Earn coins": every way to get coins, with the reward for each.
class RewardsEarnSection extends StatefulWidget {
  const RewardsEarnSection({super.key});

  @override
  State<RewardsEarnSection> createState() => _RewardsEarnSectionState();
}

class _RewardsEarnSectionState extends State<RewardsEarnSection> {
  bool _loadingReward = false;
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _onWatchAdTapped() async {
    if (_loadingReward) return;
    setState(() => _loadingReward = true);
    await _watchRewardedAdAndCreditCoins();
    if (mounted) {
      setState(() => _loadingReward = false);
    }
  }

  Future<void> _watchRewardedAdAndCreditCoins() async {
    final String owner = app_state.prismUser.id;
    int creditedCoins = 0;
    final bool credited = await CoinGate.forContext(context).watchAdForCoins(
      sourceTag: 'coins.hub.rewarded_ad',
      upsellSource: 'coin_hub_rewarded_ad',
      isMounted: () => mounted,
      adErrorMessage: context.l10n.economyAdNotCompleted,
      onCredited: (amount) => creditedCoins = amount,
    );
    if (!mounted) return;
    if (credited && owner == app_state.prismUser.id && creditedCoins > 0) {
      toasts.success(context.l10n.economyCoinsEarned(creditedCoins));
    }
  }

  void _openUploadSheet() {
    showPrismSheet<void>(context, builder: (_) => const UploadBottomPanel());
  }

  @override
  Widget build(BuildContext context) {
    final coins = CoinsService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([coins.earnFlagsNotifier, coins.adsRemainingNotifier, EconomyConfig.notifier]),
      builder: (context, _) => _buildRows(context, coins.earnFlagsNotifier.value),
    );
  }

  Widget _buildRows(BuildContext context, CoinEarnFlags flags) {
    final bool isPro = app_state.prismUser.premium;
    final String proMultiplier = '${EconomyConfig.current.award.proStreakMultiplier}';
    final CoinEventWindow? liveEvent = EconomyConfig.current.coinEvents.liveAt(_now);
    final List<Widget> rows = <Widget>[
      if (!DailyMomentConfig.enabled)
        _EarnRow(
          icon: Icons.local_fire_department_rounded,
          title: context.l10n.economyDailyStreak,
          subtitle: isPro ? context.l10n.economyOpenDailyPro(proMultiplier) : context.l10n.economyOpenDaily,
          reward: context.l10n.economyCoinsRange(CoinPolicy.streakDay1To2Daily, CoinPolicy.streakDay7Daily),
        ),
      if (!DailyMomentConfig.enabled)
        _EarnRow(
          icon: Icons.redeem_rounded,
          title: context.l10n.economyDay7Chest,
          subtitle: context.l10n.economyFinishStreakWeek,
          reward: context.l10n.economyCoinsRange(CoinPolicy.streakChestMin, CoinPolicy.streakChestMax),
        ),
      if (isPro && !DailyMomentConfig.enabled)
        _EarnRow(
          icon: Icons.workspace_premium_rounded,
          title: context.l10n.economyFreeDailySpin,
          subtitle: context.l10n.economyOnceADay,
          reward: context.l10n.economyUpToCoins(maxWheelCoins(CoinPolicy.spinWheel)),
        ),
      _EarnRow(
        icon: Icons.play_circle_outline_rounded,
        title: context.l10n.economyAd,
        subtitle: _loadingReward
            ? context.l10n.economyLoadingVideo
            : CoinsService.instance.adsRemainingToday == 0
            ? context.l10n.economyAdDailyLimit
            : context.l10n.economyWatchAdForCoins(CoinsService.instance.adsRewardNow),
        reward: context.l10n.economyCoinReward(CoinsService.instance.adsRewardNow),
        rewardLabel: context.l10n.economyCoinsEarned(CoinsService.instance.adsRewardNow),
        badge: liveEvent == null ? null : context.l10n.coinEventAdBadge(liveEvent.multiplier),
        badgeLabel: liveEvent == null ? null : context.l10n.coinEventAdBadgeLabel(liveEvent.multiplier),
        loading: _loadingReward,
        onTap: CoinsService.instance.adsRemainingToday == 0 ? null : _onWatchAdTapped,
      ),
      _EarnRow(
        icon: Icons.group_add_rounded,
        title: context.l10n.economyInviteFriend,
        subtitle: context.l10n.economyReferralBothGet(CoinPolicy.referral),
        reward: context.l10n.economyCoinReward(CoinPolicy.referral),
        rewardLabel: context.l10n.economyCoinsEarned(CoinPolicy.referral),
        onTap: () => context.router.root.push(const SharePrismRoute()),
      ),
      _EarnRow(
        icon: Icons.upload_rounded,
        title: context.l10n.economyFirstUpload,
        subtitle: flags.firstUploadRewarded ? context.l10n.actionDone : context.l10n.economyShareWallpaper,
        reward: context.l10n.economyCoinReward(CoinPolicy.firstWallpaperUpload),
        rewardLabel: context.l10n.economyCoinsEarned(CoinPolicy.firstWallpaperUpload),
        done: flags.firstUploadRewarded,
        onTap: _openUploadSheet,
      ),
      _EarnRow(
        icon: Icons.person_outline_rounded,
        title: context.l10n.economyCompleteProfile,
        subtitle: flags.profileCompletionRewarded ? context.l10n.actionDone : context.l10n.economyAddPhotoBio,
        reward: context.l10n.economyCoinReward(CoinPolicy.profileCompletion),
        rewardLabel: context.l10n.economyCoinsEarned(CoinPolicy.profileCompletion),
        done: flags.profileCompletionRewarded,
        onTap: () => context.router.root.push(const EditProfilePanelRoute()),
      ),
      _EarnRow(
        icon: Icons.redeem_rounded,
        title: context.l10n.promoRewardsRowTitle,
        subtitle: context.l10n.promoRewardsRowSubtitle,
        onTap: () => showRedeemCodeSheet(context, source: RedeemSheetSource.rewards),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(
          title: context.l10n.economyEarnCoins,
          padding: const EdgeInsets.only(top: PrismSpace.xxl, bottom: PrismSpace.sm),
        ),
        CoinEventBanner(schedule: EconomyConfig.current.coinEvents, now: _now),
        PrismGroup(children: rows),
      ],
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.reward,
    this.rewardLabel,
    this.onTap,
    this.loading = false,
    this.done = false,
    this.badge,
    this.badgeLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Null for a row with no fixed coin reward, so no reward pill shows.
  final String? reward;

  /// What a screen reader says for [reward], which shows as a bare "+20" next to the coin icon.
  final String? rewardLabel;
  final VoidCallback? onTap;
  final bool loading;
  final bool done;

  /// Short event badge on the reward pill, like "2x". Null when no event is live.
  final String? badge;

  /// What a screen reader says for [badge].
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final bool tappable = onTap != null && !done && !loading;
    final Widget trailing;
    if (done) {
      trailing = const Icon(Icons.check_rounded, key: ValueKey<String>('done'), size: 22, color: PrismColors.success);
    } else if (loading) {
      trailing = const PrismLoader(key: ValueKey<String>('loading'), size: 20);
    } else if (reward == null) {
      trailing = const SizedBox.shrink(key: ValueKey<String>('no-reward'));
    } else {
      trailing = _RewardPill(
        key: const ValueKey<String>('reward'),
        reward: reward!,
        label: rewardLabel,
        badge: badge,
        badgeLabel: badgeLabel,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => PrismRow(
        trailingBelow: MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.3 || constraints.maxWidth < 360,
        icon: icon,
        title: title,
        subtitle: done ? context.l10n.actionDone : subtitle,
        trailing: AnimatedSwitcher(duration: context.motion(PrismDurations.fast), child: trailing),
        showChevron: tappable,
        onTap: tappable
            ? () {
                PrismHaptics.tap();
                onTap?.call();
              }
            : null,
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({super.key, required this.reward, this.label, this.badge, this.badgeLabel});

  final String reward;
  final String? label;
  final String? badge;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? eventBadge = badge;
    return Semantics(
      label: badgeLabel == null ? (label ?? reward) : '$badgeLabel, ${label ?? reward}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (eventBadge != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: 2),
                decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(PrismRadius.pill)),
                child: Text(
                  eventBadge,
                  style: PrismTextStyles.caption(context).copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: PrismSpace.xxs),
            ],
            Flexible(
              child: Text(reward, style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: PrismSpace.xxs),
            const PrismCoinIcon(size: 14),
          ],
        ),
      ),
    );
  }
}
