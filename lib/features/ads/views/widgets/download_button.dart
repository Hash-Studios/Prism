import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DownloadButton extends StatefulWidget {
  const DownloadButton({
    required this.link,
    this.isPremiumContent = false,
    this.contentId,
    this.sourceContext,
    this.onDownloaded,
    super.key,
  });

  final String? link;
  final bool isPremiumContent;
  final String? contentId;
  final String? sourceContext;
  final VoidCallback? onDownloaded;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

enum _LowBalanceAction { none, downloadNow, watchAndDownload, upgrade }

class _DownloadButtonState extends State<DownloadButton> {
  bool isLoading = false;

  CoinSpendAction get _downloadSpendAction =>
      widget.isPremiumContent ? CoinSpendAction.premiumWallpaperDownload : CoinSpendAction.wallpaperDownload;

  int get _downloadCost => _downloadSpendAction.cost();

  @override
  Widget build(BuildContext context) {
    return CircularMenuButton(
      label: 'Download',
      onTap: _handleTap,
      isLoading: isLoading,
      child: Icon(JamIcons.download, color: Theme.of(context).colorScheme.secondary, size: 20),
    );
  }

  Future<void> _handleTap() async {
    if (isLoading) {
      toasts.error('Wait for download to complete!');
      return;
    }

    final String link = widget.link?.trim() ?? '';
    if (link.isEmpty) {
      toasts.error('No download link available.');
      return;
    }

    if (mounted) {
      setState(() => isLoading = true);
    }
    try {
      if (app_state.prismUser.premium) {
        await _performDownload();
        return;
      }

      if (!app_state.prismUser.loggedIn) {
        await _showGuestAdGatePopup();
        return;
      }

      final int balance = CoinsService.instance.balanceNotifier.value;
      if (balance < CoinPolicy.lowBalanceNudgeThreshold) {
        final bool handled = await _showLowBalanceNudge(
          requiredCoins: _downloadCost,
          allowDownloadNow: balance >= _downloadCost,
          sourceTag: 'coins.download.low_balance_nudge',
        );
        if (handled) {
          return;
        }
      }

      if (balance < _downloadCost) {
        await _showLowBalanceNudge(
          requiredCoins: _downloadCost,
          allowDownloadNow: false,
          sourceTag: 'coins.download.insufficient_balance_nudge',
        );
        return;
      }

      await _attemptCoinSpendAndDownload(sourceTag: 'coins.download.spend');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showGuestAdGatePopup() async {
    Future<bool>? pendingDownload;
    await showModal<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        bool watchingAd = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context).primaryColor,
                ),
                width: MediaQuery.of(context).size.width * .78,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: 150,
                      width: MediaQuery.of(context).size.width * .78,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        color: Theme.of(context).hintColor,
                      ),
                      child: const Center(child: Icon(Icons.system_update_alt)),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Watch a small video ad to download this wallpaper.',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        MaterialButton(
                          shape: const StadiumBorder(),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            PaywallOrchestrator.instance.presentOrRequireSignIn(
                              this.context,
                              placement: PaywallPlacement.mainUpsell,
                              source: 'download_guest_buy_premium',
                            );
                          },
                          child: Text(
                            'BUY PREMIUM',
                            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary),
                          ),
                        ),
                        MaterialButton(
                          shape: const StadiumBorder(),
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                          onPressed: watchingAd
                              ? null
                              : () async {
                                  setDialogState(() => watchingAd = true);
                                  final bool watched = await watchRewardedAd(context.read<AdsBloc>());
                                  if (!context.mounted || !mounted) return;
                                  setDialogState(() => watchingAd = false);
                                  if (!watched) {
                                    toasts.error('Ad was not completed.');
                                    return;
                                  }
                                  if (!dialogContext.mounted) {
                                    return;
                                  }
                                  if (Navigator.of(dialogContext).canPop()) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                  pendingDownload = _performDownload();
                                  await pendingDownload;
                                },
                          child: AnimatedSwitcher(
                            duration: context.motion(PrismDurations.fast),
                            child: watchingAd
                                ? const SizedBox(
                                    key: ValueKey<bool>(true),
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    'WATCH AD',
                                    key: const ValueKey<bool>(false),
                                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (pendingDownload != null) await pendingDownload;
  }

  Future<bool> _showLowBalanceNudge({
    required int requiredCoins,
    required bool allowDownloadNow,
    required String sourceTag,
  }) async {
    if (!mounted) {
      return false;
    }

    CoinsService.instance.logLowBalanceNudge(sourceTag: sourceTag, requiredCoins: requiredCoins);

    final _LowBalanceAction action =
        await showCoinGateSheet<_LowBalanceAction>(
          context,
          title: 'Low coin balance',
          cost: requiredCoins,
          message: (missing) => missing > 0
              ? 'You need $missing more coins for this download.'
              : 'You are below ${CoinPolicy.lowBalanceNudgeThreshold} coins.',
          options: [
            if (allowDownloadNow)
              CoinGateOption(label: 'Download (-$requiredCoins)', value: _LowBalanceAction.downloadNow),
            const CoinGateOption(
              label: 'Watch & Download (+${CoinPolicy.rewardedAd})',
              value: _LowBalanceAction.watchAndDownload,
            ),
            const CoinGateOption(label: 'Upgrade to Pro', value: _LowBalanceAction.upgrade, outlined: true),
          ],
        ) ??
        _LowBalanceAction.none;

    switch (action) {
      case _LowBalanceAction.downloadNow:
        await _attemptCoinSpendAndDownload(
          sourceTag: 'coins.download.nudge_download_now',
          showNudgeOnInsufficient: false,
        );
        return true;
      case _LowBalanceAction.watchAndDownload:
        CoinsService.instance.logWatchAndDownloadUsed(
          isPremiumContent: widget.isPremiumContent,
          sourceTag: 'coins.download.watch_and_download',
        );
        await _handleWatchAndDownload(requiredCoins: requiredCoins);
        return true;
      case _LowBalanceAction.upgrade:
        if (mounted) {
          await PaywallOrchestrator.instance.present(
            placement: PaywallPlacement.lowBalance,
            source: 'download_low_balance_upgrade',
          );
        }
        return true;
      case _LowBalanceAction.none:
        return false;
    }
  }

  Future<void> _handleWatchAndDownload({required int requiredCoins}) async {
    final bool watched = await watchRewardedAd(context.read<AdsBloc>());
    if (!watched) {
      toasts.error('Ad was not completed.');
      return;
    }

    try {
      final credit = await CoinsService.instance.award(
        CoinEarnAction.rewardedAd,
        sourceTag: 'coins.download.watch_and_download.rewarded_ad',
      );
      if (!credit.changed) {
        toasts.error('Unable to credit coins right now.');
        return;
      }
      if (mounted) {
        await PaywallOrchestrator.instance.recordRewardedAdWatchAndMaybeUpsell(
          source: 'download_watch_and_download_rewarded_ad',
        );
      }
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(
        sourceTag: 'coins.download.watch_and_download.rewarded_ad',
        error: error,
        stackTrace: stackTrace,
      );
      toasts.error('Unable to credit coins right now.');
      return;
    }

    final int balance = CoinsService.instance.balanceNotifier.value;
    if (balance < requiredCoins) {
      toasts.error('Need ${requiredCoins - balance} more coins.');
      return;
    }

    await _attemptCoinSpendAndDownload(
      sourceTag: 'coins.download.watch_and_download.spend',
      showNudgeOnInsufficient: false,
    );
  }

  Future<bool> _attemptCoinSpendAndDownload({required String sourceTag, bool showNudgeOnInsufficient = true}) async {
    final CoinSpendAction spendAction = _downloadSpendAction;
    final int spendCost = spendAction.cost();
    final String contentId = widget.contentId?.trim() ?? '';
    CoinMutationResult spendResult;
    try {
      spendResult = await CoinsService.instance.spend(
        spendAction,
        sourceTag: sourceTag,
        reason: contentId.isEmpty ? null : 'content_$contentId',
      );
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(sourceTag: sourceTag, error: error, stackTrace: stackTrace);
      if (mounted) toasts.error('Unable to process coins right now.');
      return false;
    }

    if (!spendResult.success) {
      if (spendResult.insufficientBalance) {
        if (showNudgeOnInsufficient && mounted) {
          await _showLowBalanceNudge(
            requiredCoins: spendCost,
            allowDownloadNow: false,
            sourceTag: 'coins.download.insufficient_balance_nudge',
          );
        }
        return false;
      }
      if (mounted) toasts.error('Unable to process coins right now.');
      return false;
    }

    final bool downloaded = await _performDownload();
    if (!downloaded && spendResult.changed) {
      try {
        final CoinMutationResult refundResult = await CoinsService.instance.refundSpend(
          spendAction,
          transactionId: spendResult.transactionId,
          sourceTag: '$sourceTag.refund',
          reason: 'download_failed_refund',
        );
        if (refundResult.success && refundResult.changed) {
          if (mounted) toasts.success('Download failed. ${refundResult.delta} coins refunded.');
        } else {
          CoinsService.instance.logCoinError(
            sourceTag: '$sourceTag.refund',
            error: StateError('Coin refund was not applied: ${refundResult.reason}'),
          );
          if (mounted) toasts.error('Download failed. Your refund could not be confirmed.');
        }
      } catch (error, stackTrace) {
        CoinsService.instance.logCoinError(sourceTag: '$sourceTag.refund', error: error, stackTrace: stackTrace);
        if (mounted) toasts.error('Download failed. Your refund could not be confirmed.');
      }
    }
    return downloaded;
  }

  Future<bool> _performDownload() async {
    final String link = widget.link?.trim() ?? '';
    final String? sourceContext = widget.sourceContext;
    final bool premiumContent = widget.isPremiumContent;
    final VoidCallback? onDownloaded = widget.onDownloaded;
    if (link.isEmpty) {
      toasts.error('No download link available.');
      return false;
    }

    try {
      if (link.contains('com.hash.prism')) {
        final SaveMediaRequest request = SaveMediaRequest(link: link, isLocalFile: true, kind: SaveMediaKind.wallpaper);
        final OperationResult result = await PrismMediaHostApi().saveMedia(request);
        if (!result.success) {
          if (mounted) toasts.error("Couldn't download! Please retry.");
          return false;
        }
      } else {
        final DownloadRequest request = DownloadRequest(link: link, filenameWithoutExtension: downloadBaseName(link));
        final OperationResult result = await PrismMediaHostApi().enqueueDownload(request);
        if (!result.success) {
          if (mounted) toasts.error(result.message ?? "Couldn't download! Please retry.");
          return false;
        }
      }
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        logger.w('Download channel unavailable (native side not registered)', error: e);
      } else {
        logger.e('Download failed', error: e);
      }
      if (mounted) toasts.error("Couldn't download! Please retry.");
      return false;
    } catch (e, stackTrace) {
      logger.e('Unexpected download failure', error: e, stackTrace: stackTrace);
      if (mounted) toasts.error('Something went wrong!');
      return false;
    }

    try {
      analytics.track(
        DownloadWallpaperEvent(
          link: link,
          sourceContext: (sourceContext ?? '').trim().isEmpty ? null : sourceContext,
          premiumContent: premiumContent,
        ),
      );
    } catch (e, stackTrace) {
      logger.w('Download analytics failed after media was saved', error: e, stackTrace: stackTrace);
    }

    if (mounted) {
      try {
        toasts.success(wallpaperSavedMessage);
        onDownloaded?.call();
      } catch (e, stackTrace) {
        logger.w('Download follow-up failed after media was saved', error: e, stackTrace: stackTrace);
      }
      try {
        await NotificationPermissionPromptService.instance.maybePromptAfterValueAction(
          context,
          sourceTag: 'notifications.permission_after_download',
        );
      } catch (e, stackTrace) {
        logger.w('Notification permission prompt after download failed', error: e, stackTrace: stackTrace);
      }
    }
    return true;
  }
}
