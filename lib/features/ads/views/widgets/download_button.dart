import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
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
    this.label,
    super.key,
  });

  final String? link;
  final bool isPremiumContent;
  final String? contentId;
  final String? sourceContext;
  final VoidCallback? onDownloaded;

  /// Text shown beside the circle. It sits inside the same tap target, so tapping it starts the download.
  final String? label;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  bool isLoading = false;

  CoinSpendAction get _downloadSpendAction =>
      widget.isPremiumContent ? CoinSpendAction.premiumWallpaperDownload : CoinSpendAction.wallpaperDownload;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? label = widget.label;
    final Widget icon = Icon(JamIcons.download, color: theme.colorScheme.secondary, size: 20);
    if (label == null) {
      return CircularMenuButton(label: 'Download', onTap: _handleTap, isLoading: isLoading, child: icon);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: PrimaryActionPill(icon: JamIcons.download, label: label, semanticLabel: 'Download', isLoading: isLoading),
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
    PrismHaptics.tap();

    if (mounted) {
      setState(() => isLoading = true);
    }
    try {
      if (!app_state.prismUser.premium && !app_state.prismUser.loggedIn) {
        await _showGuestAdGatePopup();
        return;
      }
      await _gatedDownload();
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
                            PrismHaptics.tap();
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
                                  PrismHaptics.tap();
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

  Future<CoinGateChoice> _chooseLowBalanceAction(CoinGatePrompt prompt) async {
    final bool allowDownloadNow = prompt.phase == CoinGatePhase.nudge && prompt.canSpend;
    final CoinGateChoice? choice = await showCoinGateSheet<CoinGateChoice>(
      context,
      title: 'Low coin balance',
      cost: prompt.cost,
      message: (missing) => missing > 0
          ? 'You need $missing more coins for this download.'
          : 'You are below ${CoinPolicy.lowBalanceNudgeThreshold} coins.',
      options: [
        if (allowDownloadNow) CoinGateOption(label: 'Download (-${prompt.cost})', value: CoinGateChoice.spend),
        const CoinGateOption(label: 'Watch & Download (+${CoinPolicy.rewardedAd})', value: CoinGateChoice.watchAd),
        const CoinGateOption(label: 'Upgrade to Pro', value: CoinGateChoice.upgrade, outlined: true),
      ],
    );
    return choice ?? (prompt.phase == CoinGatePhase.nudge ? CoinGateChoice.proceed : CoinGateChoice.cancel);
  }

  Future<void> _gatedDownload() {
    final String contentId = widget.contentId?.trim() ?? '';
    return CoinGate.forContext(context).run(
      CoinGateSpec(
        action: _downloadSpendAction,
        reason: contentId.isEmpty ? null : 'content_$contentId',
        tags: const CoinGateTags(
          spend: 'coins.download.spend',
          nudgeSpend: 'coins.download.nudge_download_now',
          retrySpend: 'coins.download.watch_and_download.spend',
          ad: 'coins.download.watch_and_download.rewarded_ad',
          nudge: 'coins.download.low_balance_nudge',
          insufficient: 'coins.download.insufficient_balance_nudge',
        ),
        upsellSource: 'download_watch_and_download_rewarded_ad',
        upgradeSource: 'download_low_balance_upgrade',
        nudgeBelow: CoinPolicy.lowBalanceNudgeThreshold,
        precheckBalance: true,
        repromptOnNudgeSpendInsufficient: false,
        isMounted: () => mounted,
        perform: _performDownload,
        choose: _chooseLowBalanceAction,
        onWatchChosen: () => CoinsService.instance.logWatchAndDownloadUsed(
          isPremiumContent: widget.isPremiumContent,
          sourceTag: 'coins.download.watch_and_download',
        ),
      ),
    );
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
      final Uri? source = Uri.tryParse(link);
      if (link.startsWith('/') || source?.scheme == 'file') {
        final SaveMediaRequest request = SaveMediaRequest(link: link, isLocalFile: true, kind: SaveMediaKind.wallpaper);
        final OperationResult result = await PrismMediaHostApi().saveMedia(request);
        if (!result.success) {
          if (isPhotosPermissionDenied(result.errorCode)) {
            if (mounted) showPhotosPermissionDenied(context);
          } else {
            toasts.error("Couldn't download! Please retry.");
          }
          return false;
        }
      } else {
        final DownloadRequest request = DownloadRequest(link: link, filenameWithoutExtension: downloadBaseName(link));
        final OperationResult result = await PrismMediaHostApi().enqueueDownload(request);
        if (!result.success) {
          if (isPhotosPermissionDenied(result.errorCode)) {
            if (mounted) showPhotosPermissionDenied(context);
          } else {
            toasts.error(result.message ?? "Couldn't download! Please retry.");
          }
          return false;
        }
      }
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        logger.w('Download channel unavailable (native side not registered)', error: e);
      } else {
        logger.e('Download failed', error: e);
      }
      toasts.error("Couldn't download! Please retry.");
      return false;
    } catch (e, stackTrace) {
      logger.e('Unexpected download failure', error: e, stackTrace: stackTrace);
      toasts.error('Something went wrong!');
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

    try {
      toasts.success(wallpaperSavedMessage);
      onDownloaded?.call();
    } catch (e, stackTrace) {
      logger.w('Download follow-up failed after media was saved', error: e, stackTrace: stackTrace);
    }
    if (mounted) {
      try {
        await showIosSetWallpaperGuide(context);
      } catch (e, stackTrace) {
        logger.w('iOS wallpaper guide failed after media was saved', error: e, stackTrace: stackTrace);
      }
    }
    if (mounted) {
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
