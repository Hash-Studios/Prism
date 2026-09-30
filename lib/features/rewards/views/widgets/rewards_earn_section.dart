import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
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
    final bool credited = await CoinGate.forContext(context).watchAdForCoins(
      sourceTag: 'coins.hub.rewarded_ad',
      upsellSource: 'coin_hub_rewarded_ad',
      isMounted: () => mounted,
    );
    if (credited) {
      toasts.success('+${CoinPolicy.rewardedAd} coins');
    }
  }

  void _openUploadSheet() {
    showPrismSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).primaryColor,
      builder: (_) => const UploadBottomPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CoinEarnFlags>(
      valueListenable: CoinsService.instance.earnFlagsNotifier,
      builder: (context, flags, _) => _buildRows(context, flags),
    );
  }

  Widget _buildRows(BuildContext context, CoinEarnFlags flags) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Widget> rows = <Widget>[
      const _EarnRow(
        icon: Icons.local_fire_department_rounded,
        title: 'Daily streak',
        subtitle: 'Open Prism every day · +${CoinPolicy.streak7Bonus} each week',
        reward: '+${CoinPolicy.streakDay1To2Daily} to +${CoinPolicy.streakDay7Daily}',
      ),
      _EarnRow(
        icon: Icons.play_circle_outline_rounded,
        title: 'Watch a video',
        subtitle: 'Up to 20 a day',
        reward: '+${CoinPolicy.rewardedAd}',
        loading: _loadingReward,
        onTap: _onWatchAdTapped,
      ),
      _EarnRow(
        icon: Icons.group_add_outlined,
        title: 'Invite a friend',
        subtitle: 'You both get ${CoinPolicy.referral}',
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
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Earn coins', style: PrismTextStyles.sectionTitle(context)),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < rows.length; i++) ...<Widget>[
                      if (i > 0) Divider(height: 1, thickness: 1, color: scheme.onSurface.withValues(alpha: 0.08)),
                      rows[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool tappable = onTap != null && !done && !loading;
    final Widget trailing;
    if (done) {
      trailing = Icon(Icons.check_rounded, size: 20, color: scheme.onSurface.withValues(alpha: 0.55));
    } else if (loading) {
      trailing = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const PrismCoinIcon(size: 14),
                const SizedBox(width: 5),
                Text(reward, style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: scheme.onSurface.withValues(alpha: 0.45)),
          ],
        ],
      );
    }
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: scheme.onSurface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: PrismTextStyles.rowTitle(context)),
                const SizedBox(height: 2),
                Text(
                  done ? 'Done' : subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.caption(context).copyWith(height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(duration: context.motion(PrismDurations.fast), child: trailing),
        ],
      ),
    );
    return Semantics(
      button: tappable,
      container: true,
      child: Opacity(
        opacity: done ? 0.55 : 1,
        child: tappable
            ? PressScale(
                scale: 0.98,
                child: InkWell(onTap: onTap, child: content),
              )
            : content,
      ),
    );
  }
}
