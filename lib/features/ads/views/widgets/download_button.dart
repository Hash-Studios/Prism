import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/common/safe_rive_asset.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadButton extends StatefulWidget {
  const DownloadButton({
    required this.link,
    required this.colorChanged,
    this.isPremiumContent = false,
    this.contentId,
    this.sourceContext,
    super.key,
  });

  final String? link;
  final bool colorChanged;
  final bool isPremiumContent;
  final String? contentId;
  final String? sourceContext;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

enum _LowBalanceAction { none, downloadNow, watchAndDownload, upgrade }

class _DownloadButtonState extends State<DownloadButton> {
  late bool isLoading;

  CoinSpendAction get _downloadSpendAction =>
      widget.isPremiumContent ? CoinSpendAction.premiumWallpaperDownload : CoinSpendAction.wallpaperDownload;

  int get _downloadCost => _downloadSpendAction.cost();

  @override
  void initState() {
    super.initState();
    isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4)),
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: const EdgeInsets.all(17),
            child: Icon(JamIcons.download, color: Theme.of(context).colorScheme.secondary, size: 20),
          ),
          Positioned(
            top: 0,
            left: 0,
            height: 53,
            width: 53,
            child: isLoading ? const CircularProgressIndicator() : Container(),
          ),
        ],
      ),
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

    if (!app_state.prismUser.loggedIn) {
      await _showGuestAdGatePopup();
      return;
    }

    if (app_state.prismUser.premium) {
      await _performDownload();
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
  }

  Future<void> _showGuestAdGatePopup() async {
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
                      child: const SafeRiveAsset(
                        assetName: 'assets/animations/Update.flr',
                        animations: <String>['update'],
                      ),
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
                            if (app_state.prismUser.loggedIn == false) {
                              googleSignInPopUp(context, () {
                                Navigator.of(dialogContext).pop();
                                PaywallOrchestrator.instance.present(
                                  this.context,
                                  placement: PaywallPlacement.mainUpsell,
                                  source: 'download_guest_buy_premium',
                                );
                              });
                            } else {
                              Navigator.of(dialogContext).pop();
                              PaywallOrchestrator.instance.present(
                                this.context,
                                placement: PaywallPlacement.mainUpsell,
                                source: 'download_guest_buy_premium',
                              );
                            }
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
                                  final bool watched = await _watchRewardedAd();
                                  if (mounted) {
                                    setDialogState(() => watchingAd = false);
                                  }
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
                                  await _performDownload();
                                },
                          child: watchingAd
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  'WATCH AD',
                                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary),
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
        await showModalBottomSheet<_LowBalanceAction>(
          context: context,
          backgroundColor: Theme.of(context).primaryColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (sheetContext) {
            final int balance = CoinsService.instance.balanceNotifier.value;
            final int missing = (requiredCoins - balance).clamp(0, requiredCoins);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext).hintColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Low coin balance', style: Theme.of(sheetContext).textTheme.displaySmall),
                  const SizedBox(height: 10),
                  Text(
                    missing > 0
                        ? 'You need $missing more coins for this download.'
                        : 'You are below ${CoinPolicy.lowBalanceNudgeThreshold} coins.',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (allowDownloadNow)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(_LowBalanceAction.downloadNow),
                        child: Text('Download (-$requiredCoins)'),
                      ),
                    ),
                  if (allowDownloadNow) const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(_LowBalanceAction.watchAndDownload),
                      child: const Text('Watch & Download (+10)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(_LowBalanceAction.upgrade),
                      child: const Text('Upgrade to Pro'),
                    ),
                  ),
                ],
              ),
            );
          },
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
            context,
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
    final bool watched = await _watchRewardedAd();
    if (!watched) {
      toasts.error('Ad was not completed.');
      return;
    }

    try {
      await CoinsService.instance.award(
        CoinEarnAction.rewardedAd,
        sourceTag: 'coins.download.watch_and_download.rewarded_ad',
      );
      if (mounted) {
        await PaywallOrchestrator.instance.recordRewardedAdWatchAndMaybeUpsell(
          context,
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
    CoinMutationResult spendResult;
    try {
      spendResult = await CoinsService.instance.spend(
        _downloadSpendAction,
        sourceTag: sourceTag,
        reason: widget.contentId?.trim().isNotEmpty == true ? 'content_${widget.contentId!.trim()}' : null,
      );
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(sourceTag: sourceTag, error: error, stackTrace: stackTrace);
      toasts.error('Unable to process coins right now.');
      return false;
    }

    if (!spendResult.success) {
      if (spendResult.insufficientBalance) {
        if (showNudgeOnInsufficient) {
          await _showLowBalanceNudge(
            requiredCoins: _downloadCost,
            allowDownloadNow: false,
            sourceTag: 'coins.download.insufficient_balance_nudge',
          );
        }
        return false;
      }
      toasts.error('Unable to process coins right now.');
      return false;
    }

    final bool downloaded = await _performDownload();
    if (!downloaded && spendResult.changed) {
      try {
        await CoinsService.instance.refundSpend(
          _downloadSpendAction,
          sourceTag: '$sourceTag.refund',
          reason: 'download_failed_refund',
        );
        toasts.codeSend('Download failed. $_downloadCost coins refunded.');
      } catch (error, stackTrace) {
        CoinsService.instance.logCoinError(sourceTag: '$sourceTag.refund', error: error, stackTrace: stackTrace);
      }
    }
    return downloaded;
  }

  Future<bool> _ensureRewardedAdReady(AdsBloc bloc) async {
    if (bloc.state.ads.adLoaded) {
      return true;
    }
    if (!bloc.state.ads.loadingAd) {
      bloc.add(const AdsEvent.started());
    }
    try {
      final AdsState state = await bloc.stream
          .firstWhere((state) => state.ads.adLoaded || state.ads.adFailed)
          .timeout(const Duration(seconds: 30));
      return state.ads.adLoaded;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _watchRewardedAd() async {
    final AdsBloc bloc = context.read<AdsBloc>();
    if (!await _ensureRewardedAdReady(bloc)) {
      return false;
    }
    bool watchRequested = false;
    try {
      final Future<AdsState> completion = bloc.stream
          .firstWhere(
            (state) => state.shouldUnlockDownload || state.actionStatus == ActionStatus.failure || state.ads.adFailed,
          )
          .timeout(const Duration(seconds: 60));
      bloc.add(const AdsEvent.watchAdRequested());
      watchRequested = true;
      final AdsState result = await completion;
      return result.shouldUnlockDownload;
    } catch (_) {
      return false;
    } finally {
      if (watchRequested) {
        bloc.add(const AdsEvent.transientStateCleared());
      }
    }
  }

  Future<bool> _ensureStoragePermission() async {
    final PermissionStatus status = await Permission.storage.status;
    if (status.isGranted) {
      return true;
    }
    final PermissionStatus requested = await Permission.storage.request();
    return requested.isGranted;
  }

  Future<bool> _performDownload() async {
    final String link = widget.link?.trim() ?? '';
    if (link.isEmpty) {
      toasts.error('No download link available.');
      return false;
    }

    final bool storageGranted = await _ensureStoragePermission();
    if (!storageGranted) {
      toasts.error('Storage permission is required to download.');
      return false;
    }

    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      logger.d(link);
      if (link.contains('com.hash.prism')) {
        final SaveMediaRequest request = SaveMediaRequest(link: link, isLocalFile: true, kind: SaveMediaKind.wallpaper);
        final OperationResult result = await PrismMediaHostApi().saveMedia(request);
        if (!result.success) {
          toasts.error("Couldn't download! Please retry.");
          return false;
        }
      } else {
        final DownloadRequest request = DownloadRequest(
          link: link,
          filenameWithoutExtension: link.split('/').last.replaceAll('.jpg', '').replaceAll('.png', ''),
        );
        final OperationResult result = await PrismMediaHostApi().enqueueDownload(request);
        if (!result.success) {
          toasts.error(result.message ?? "Couldn't download! Please retry.");
          return false;
        }
      }

      analytics.track(
        DownloadWallpaperEvent(
          link: link,
          sourceContext: (widget.sourceContext ?? '').trim().isEmpty ? null : widget.sourceContext,
          premiumContent: widget.isPremiumContent,
        ),
      );
      toasts.codeSend(hideSetWallpaperUi ? 'Saved to Photos.' : 'Wall downloaded in Pictures/Prism!');
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        logger.w('Download channel unavailable (native side not registered)', error: e);
      } else {
        logger.e('Download failed', error: e);
      }
      toasts.error("Couldn't download! Please retry.");
      return false;
    } catch (e) {
      logger.e('Unexpected download failure', error: e);
      toasts.error('Something went wrong!');
      return false;
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
}
