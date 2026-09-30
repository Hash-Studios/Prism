import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/core/widgets/prism/prism_section.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    if (!await watchRewardedAd(context.read<AdsBloc>())) {
      toasts.error('Ad was not completed.');
      return;
    }
    try {
      final credit = await CoinsService.instance.award(CoinEarnAction.rewardedAd, sourceTag: 'coins.hub.rewarded_ad');
      if (!credit.changed) {
        toasts.error('Unable to credit coins right now.');
        return;
      }
      if (mounted) {
        await PaywallOrchestrator.instance.recordRewardedAdWatchAndMaybeUpsell(source: 'coin_hub_rewarded_ad');
      }
      toasts.success('+${CoinPolicy.rewardedAd} coins');
    } catch (_) {
      toasts.error('Ad was not completed.');
    }
  }

  void _openUploadSheet() {
    showPrismSheet<void>(context: context, isScrollControlled: true, builder: (_) => const UploadBottomPanel());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CoinEarnFlags>(
      valueListenable: CoinsService.instance.earnFlagsNotifier,
      builder: (context, flags, _) => _buildRows(context, flags),
    );
  }

  Widget _buildRows(BuildContext context, CoinEarnFlags flags) {
    final List<Widget> rows = <Widget>[
      const _EarnRow(
        icon: Icons.local_fire_department_rounded,
        title: 'Daily streak',
        subtitle: 'Open Prism every day. +${CoinPolicy.streak7Bonus} each week.',
        reward: '+${CoinPolicy.streakDay1To2Daily} to +${CoinPolicy.streakDay7Daily}',
      ),
      _EarnRow(
        icon: Icons.play_circle_outline_rounded,
        title: 'Watch a video',
        subtitle: _loadingReward ? 'Loading a video' : 'Up to 20 a day',
        reward: '+${CoinPolicy.rewardedAd}',
        loading: _loadingReward,
        onTap: _onWatchAdTapped,
      ),
      _EarnRow(
        icon: Icons.group_add_outlined,
        title: 'Invite a friend',
        subtitle: 'You both get ${CoinPolicy.referral} coins',
        reward: '+${CoinPolicy.referral}',
        onTap: () => context.router.root.push(const SharePrismRoute()),
      ),
      _EarnRow(
        icon: Icons.upload_rounded,
        title: 'First upload',
        subtitle: flags.firstUploadRewarded ? 'Done' : 'Share a wallpaper',
        reward: '+${CoinPolicy.firstWallpaperUpload}',
        done: flags.firstUploadRewarded,
        onTap: _openUploadSheet,
      ),
      _EarnRow(
        icon: Icons.person_outline_rounded,
        title: 'Complete your profile',
        subtitle: flags.profileCompletionRewarded ? 'Done' : 'Add a photo and a bio',
        reward: '+${CoinPolicy.profileCompletion}',
        done: flags.profileCompletionRewarded,
        onTap: () => context.router.root.push(const EditProfilePanelRoute()),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismSectionHeader(
          title: 'Earn coins',
          padding: EdgeInsets.only(top: PrismSpace.xxl, bottom: PrismSpace.sm),
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
    return PrismRow(
      icon: icon,
      title: title,
      subtitle: done ? 'Done' : subtitle,
      trailing: AnimatedSwitcher(duration: context.motion(PrismDurations.fast), child: trailing),
      showChevron: tappable,
      onTap: tappable ? onTap : null,
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
          Text(reward, style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
