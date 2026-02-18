import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CoinBalanceChip extends StatefulWidget {
  const CoinBalanceChip({
    super.key,
    required this.sourceTag,
  });

  final String sourceTag;

  @override
  State<CoinBalanceChip> createState() => _CoinBalanceChipState();
}

class _CoinBalanceChipState extends State<CoinBalanceChip> {
  bool _loadingReward = false;

  @override
  Widget build(BuildContext context) {
    if (!globals.prismUser.loggedIn) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (context, balance, _) {
        return ValueListenableBuilder<int>(
          valueListenable: CoinsService.instance.deltaNotifier,
          builder: (context, delta, __) {
            final bool isLow = !globals.prismUser.premium && balance < CoinPolicy.lowBalanceNudgeThreshold;
            final bool isEarn = delta > 0;
            final bool isSpend = delta < 0;
            final Color bgColor = isEarn
                ? Colors.green.withValues(alpha: 0.2)
                : isSpend
                    ? Colors.red.withValues(alpha: 0.2)
                    : Theme.of(context).hintColor;
            return AnimatedScale(
              scale: delta == 0 ? 1 : 1.06,
              duration: const Duration(milliseconds: 220),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    if (isLow) {
                      CoinsService.instance.logLowBalanceNudge(
                        sourceTag: widget.sourceTag,
                        requiredCoins: CoinPolicy.lowBalanceNudgeThreshold,
                      );
                    }
                    _showCoinActionsSheet(context, isLow: isLow, balance: balance);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isLow ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.secondary,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          JamIcons.coin,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$balance',
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (delta != 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            isEarn ? '+$delta' : '$delta',
                            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                  color: isEarn ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCoinActionsSheet(
    BuildContext context, {
    required bool isLow,
    required int balance,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Prism Coins: $balance',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 10),
                Text(
                  isLow
                      ? 'Low balance. Watch an ad or upgrade to Pro.'
                      : 'Use coins for downloads and premium actions.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loadingReward
                        ? null
                        : () async {
                            setState(() => _loadingReward = true);
                            await _watchRewardedAdAndCreditCoins();
                            if (mounted) {
                              setState(() => _loadingReward = false);
                            }
                          },
                    child: _loadingReward
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Watch Ad (+10)'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.router.push(const UpgradeRoute());
                    },
                    child: const Text('Upgrade to Pro'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _ensureRewardedAdReady() async {
    final AdsBloc bloc = context.read<AdsBloc>();
    if (bloc.state.ads.adLoaded) {
      return true;
    }
    if (!bloc.state.ads.loadingAd) {
      bloc.add(const AdsEvent.started());
    }
    try {
      final AdsState state = await bloc.stream
          .firstWhere(
            (state) => state.ads.adLoaded || state.ads.adFailed,
          )
          .timeout(const Duration(seconds: 30));
      return state.ads.adLoaded;
    } catch (_) {
      return false;
    }
  }

  Future<void> _watchRewardedAdAndCreditCoins() async {
    if (!await _ensureRewardedAdReady()) {
      toasts.error('Ads unavailable right now. Try again later.');
      return;
    }

    final AdsBloc bloc = context.read<AdsBloc>();
    try {
      final Future<AdsState> completion = bloc.stream
          .firstWhere(
            (state) => state.shouldUnlockDownload || state.actionStatus == ActionStatus.failure || state.ads.adFailed,
          )
          .timeout(const Duration(seconds: 60));
      bloc.add(const AdsEvent.watchAdRequested());
      final AdsState result = await completion;
      if (result.shouldUnlockDownload) {
        await CoinsService.instance.award(
          CoinEarnAction.rewardedAd,
          sourceTag: 'coins.coin_chip.rewarded_ad',
        );
        bloc.add(const AdsEvent.transientStateCleared());
        toasts.codeSend('+${CoinPolicy.rewardedAd} coins');
        return;
      }
      toasts.error('Ad was not completed.');
    } catch (_) {
      toasts.error('Ad was not completed.');
    }
  }
}
