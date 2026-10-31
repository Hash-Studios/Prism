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
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
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
    return ValueListenableBuilder<CoinEarnFlags>(
      valueListenable: CoinsService.instance.earnFlagsNotifier,
      builder: (context, flags, _) => _buildRows(context, flags),
    );
  }

  Widget _buildRows(BuildContext context, CoinEarnFlags flags) {
    final bool isPro = app_state.prismUser.premium;
    final String proMultiplier = '${EconomyConfig.current.award.proStreakMultiplier}';
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
          icon: Icons.workspace_premium_outlined,
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
        reward: context.l10n.economyCoinsEarned(CoinsService.instance.adsRewardNow),
        loading: _loadingReward,
        onTap: CoinsService.instance.adsRemainingToday == 0 ? null : _onWatchAdTapped,
      ),
      _EarnRow(
        icon: Icons.group_add_outlined,
        title: context.l10n.economyInviteFriend,
        subtitle: context.l10n.economyReferralBothGet(CoinPolicy.referral),
        reward: context.l10n.economyCoinsEarned(CoinPolicy.referral),
        onTap: () => context.router.root.push(const SharePrismRoute()),
      ),
      _EarnRow(
        icon: Icons.upload_rounded,
        title: context.l10n.economyFirstUpload,
        subtitle: flags.firstUploadRewarded ? context.l10n.actionDone : context.l10n.economyShareWallpaper,
        reward: context.l10n.economyCoinsEarned(CoinPolicy.firstWallpaperUpload),
        done: flags.firstUploadRewarded,
        onTap: _openUploadSheet,
      ),
      _EarnRow(
        icon: Icons.person_outline_rounded,
        title: context.l10n.economyCompleteProfile,
        subtitle: flags.profileCompletionRewarded ? context.l10n.actionDone : context.l10n.economyAddPhotoBio,
        reward: context.l10n.economyCoinsEarned(CoinPolicy.profileCompletion),
        done: flags.profileCompletionRewarded,
        onTap: () => context.router.root.push(const EditProfilePanelRoute()),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(
          title: context.l10n.economyEarnCoins,
          padding: const EdgeInsets.only(top: PrismSpace.xxl, bottom: PrismSpace.sm),
        ),
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
    required this.reward,
    this.onTap,
    this.loading = false,
    this.done = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String reward;
  final VoidCallback? onTap;
  final bool loading;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool tappable = onTap != null && !done && !loading;
    final Widget trailing;
    if (done) {
      trailing = const Icon(Icons.check_rounded, key: ValueKey<String>('done'), size: 22, color: PrismColors.success);
    } else if (loading) {
      trailing = SizedBox.square(
        key: const ValueKey<String>('loading'),
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      );
    } else {
      trailing = _RewardPill(key: const ValueKey<String>('reward'), reward: reward);
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
  const _RewardPill({super.key, required this.reward});

  final String reward;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm - 2, vertical: PrismSpace.xxs),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const PrismCoinIcon(size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(reward, style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
