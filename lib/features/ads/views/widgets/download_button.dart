import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

class DownloadButton extends StatefulWidget {
  const DownloadButton({
    required this.link,
    this.isPremiumContent = false,
    this.contentId,
    this.sourceContext,
    this.onDownloaded,
    this.label,
    this.wallpaperTitle,
    this.creatorName,
    this.onOpenDownloads,
    super.key,
  });

  final String? link;
  final bool isPremiumContent;
  final String? contentId;
  final String? sourceContext;
  final VoidCallback? onDownloaded;

  /// Text shown beside the circle. It sits inside the same tap target, so tapping it starts the download.
  final String? label;

  /// Names the coin history row of the spend. Without it the row reads "Wallpaper by" plus the creator name.
  final String? wallpaperTitle;
  final String? creatorName;

  /// Replaces the push to the Downloads route when the user taps "Open" on a wallpaper they already saved.
  @visibleForTesting
  final VoidCallback? onOpenDownloads;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

enum _SavedChoice { open, again }

enum _GuestProChoice { signIn, pro }

class _DownloadButtonState extends State<DownloadButton> {
  bool isLoading = false;
  bool _saved = false;
  String? _failureReason;
  String _failureStage = 'download';

  CoinSpendAction get _downloadSpendAction =>
      widget.isPremiumContent ? CoinSpendAction.premiumWallpaperDownload : CoinSpendAction.wallpaperDownload;

  @override
  void initState() {
    super.initState();
    _saved = _isSaved(widget.link);
  }

  @override
  void didUpdateWidget(DownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link != widget.link) _saved = _isSaved(widget.link);
  }

  bool _isSaved(String? link) {
    final String trimmed = link?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    try {
      return CoinsService.instance.isLinkDownloaded(trimmed);
    } catch (_) {
      return false;
    }
  }

  bool get _isGuest => !app_state.prismUser.premium && !app_state.prismUser.loggedIn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? label = widget.label;
    final Widget icon = Icon(JamIcons.download, color: theme.colorScheme.secondary, size: 20);
    if (label == null) {
      return CircularMenuButton(label: 'Download', onTap: _handleTap, isLoading: isLoading, child: icon);
    }
    final int cost = _downloadSpendAction.cost();
    final bool pro = app_state.prismUser.premium;
    final String text;
    final String semantics;
    if (_saved) {
      text = 'Saved';
      semantics = 'Saved. Already in Downloads';
    } else if (pro) {
      text = 'Free with Pro';
      semantics = '$label. Free with Pro';
    } else if (_isGuest) {
      text = label;
      semantics = label;
    } else {
      text = '$label · $cost';
      semantics = '$label. Costs $cost coins';
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: PrimaryActionPill(icon: JamIcons.download, label: text, semanticLabel: semantics, isLoading: isLoading),
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
      if (!await _confirmDownloadAgain(link)) return;
      _failureReason = null;
      _failureStage = 'download';
      _track(DownloadAttemptEvent(source: _sourceLabel, premium: widget.isPremiumContent));
      if (_isGuest) {
        await _runGuestFlow();
        return;
      }
      final CoinGateResult result = await _gatedDownload();
      if (result != CoinGateResult.failedNotRefunded) await CoinsService.instance.clearPendingDownload();
      _trackGateResult(result);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String get _sourceLabel {
    final String source = widget.sourceContext?.trim() ?? '';
    return source.isEmpty ? 'unknown' : source;
  }

  void _track(AnalyticsEvent event) {
    try {
      unawaited(analytics.track(event));
    } catch (error, stackTrace) {
      logger.w('Download analytics failed', error: error, stackTrace: stackTrace);
    }
  }

  void _trackGateResult(CoinGateResult result) {
    switch (result) {
      case CoinGateResult.performed:
      case CoinGateResult.performedFree:
        _track(const DownloadResultEvent(result: 'success', stage: 'download'));
      case CoinGateResult.cancelled:
        _track(const DownloadResultEvent(result: 'cancelled', stage: 'gate'));
      case CoinGateResult.insufficient:
        _track(const DownloadResultEvent(result: 'failed', reason: 'insufficient_balance', stage: 'gate'));
      case CoinGateResult.spendFailed:
        _track(const DownloadResultEvent(result: 'failed', reason: 'spend_failed', stage: 'spend'));
      case CoinGateResult.failedRefunded:
      case CoinGateResult.failedNotRefunded:
        _track(DownloadResultEvent(result: 'failed', reason: _failureReason ?? 'unknown', stage: _failureStage));
    }
  }

  /// Asks what to do when the wallpaper is already in Downloads. Returns true to go on with a new download.
  Future<bool> _confirmDownloadAgain(String link) async {
    if (!_isSaved(link) || !await _fileStillInDownloads(link) || !mounted) return true;
    final bool free = app_state.prismUser.premium || _isGuest;
    final int cost = _downloadSpendAction.cost();
    final _SavedChoice? choice = await showCoinGateSheet<_SavedChoice>(
      context,
      title: 'Already in Downloads',
      cost: 0,
      message: (_) => 'You saved this wallpaper before.',
      options: <CoinGateOption<_SavedChoice>>[
        const CoinGateOption(label: 'Open', value: _SavedChoice.open),
        CoinGateOption(
          label: free ? 'Download again' : 'Download again (-$cost coins)',
          value: _SavedChoice.again,
          outlined: true,
        ),
      ],
    );
    if (choice == _SavedChoice.open && mounted) {
      final VoidCallback? override = widget.onOpenDownloads;
      if (override != null) {
        override();
      } else {
        unawaited(context.router.push(const DownloadRoute()));
      }
    }
    return choice == _SavedChoice.again;
  }

  /// True when the Downloads list still holds a file with this link's name. False when it cannot tell.
  Future<bool> _fileStillInDownloads(String link) async {
    try {
      final DownloadItemsResult result = await PrismMediaHostApi().listDownloads();
      if (!result.success) return false;
      final String base = downloadBaseName(link);
      final RegExp copySuffix = RegExp(r' \(\d+\)$');
      return result.items.any(
        (String path) =>
            p.basenameWithoutExtension(path).replaceFirst(copySuffix, '') == base && File(path).existsSync(),
      );
    } catch (error, stackTrace) {
      logger.w('Could not list downloads', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _runGuestFlow() async {
    if (widget.isPremiumContent) {
      await _showGuestPremiumPrompt();
      _track(const DownloadResultEvent(result: 'cancelled', stage: 'gate'));
      return;
    }
    final bool? downloaded = await _showGuestAdGatePopup();
    if (downloaded == null) {
      _track(const DownloadResultEvent(result: 'cancelled', stage: 'gate'));
    } else if (downloaded) {
      _track(const DownloadResultEvent(result: 'success', stage: 'download'));
    } else {
      _track(DownloadResultEvent(result: 'failed', reason: _failureReason ?? 'unknown', stage: _failureStage));
    }
  }

  /// Guests cannot pay for a Pro wallpaper with an ad. They sign in to use coins, or get Pro.
  Future<void> _showGuestPremiumPrompt() async {
    final _GuestProChoice? choice = await showCoinGateSheet<_GuestProChoice>(
      context,
      title: 'Pro wallpaper',
      cost: 0,
      message: (_) => 'Sign in to save this wallpaper with coins, or get Prism Pro.',
      options: const <CoinGateOption<_GuestProChoice>>[
        CoinGateOption(label: 'Sign in', value: _GuestProChoice.signIn),
        CoinGateOption(label: 'Get Pro', value: _GuestProChoice.pro, outlined: true),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case _GuestProChoice.signIn:
        googleSignInPopUp(context, () {});
      case _GuestProChoice.pro:
        await PaywallOrchestrator.instance.presentOrRequireSignIn(
          context,
          placement: PaywallPlacement.mainUpsell,
          source: 'download_guest_premium',
        );
      case null:
        break;
    }
  }

  /// Returns whether the download ran and worked, or null when the user left without one.
  Future<bool?> _showGuestAdGatePopup() async {
    Future<bool>? pendingDownload;
    final bool adsAllowed = await AdConsent.instance.ensure();
    if (!mounted) return null;
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
                    if (!adsAllowed) ...<Widget>[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Ads are off. Change this in Settings > Privacy.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
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
                        if (adsAllowed)
                          MaterialButton(
                            shape: const StadiumBorder(),
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                            onPressed: watchingAd
                                ? null
                                : () async {
                                    PrismHaptics.tap();
                                    setDialogState(() => watchingAd = true);
                                    final RewardedAdResult watched = await watchRewardedAdResult(
                                      context.read<AdsBloc>(),
                                    );
                                    if (!context.mounted || !mounted) return;
                                    setDialogState(() => watchingAd = false);
                                    if (!watched.earned) {
                                      toasts.error(adFailureMessage(watched.failure));
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
    return pendingDownload;
  }

  Future<CoinGateChoice> _chooseLowBalanceAction(CoinGatePrompt prompt) async {
    final int missing = prompt.missing;
    final int? adsLeft = prompt.adsRemaining;
    final String adNote = !prompt.adsAllowed
        ? ' Ads are off. Change this in Settings > Privacy.'
        : (adsLeft != null && adsLeft <= 0 ? ' Daily limit reached. Back tomorrow.' : '');
    final CoinGateChoice? choice = await showCoinGateSheet<CoinGateChoice>(
      context,
      title: 'Not enough coins',
      cost: prompt.cost,
      message: (int sheetMissing) {
        final String need = 'You need ${sheetMissing > 0 ? sheetMissing : missing} more coins to save this wallpaper.';
        final String perAd = sheetMissing > CoinPolicy.rewardedAd && prompt.canWatchAd
            ? ' Each ad adds ${CoinPolicy.rewardedAd}.'
            : '';
        return '$need$perAd$adNote';
      },
      options: <CoinGateOption<CoinGateChoice>>[
        if (prompt.canWatchAd)
          CoinGateOption(
            label: 'Watch ad (+${CoinPolicy.rewardedAd})${adsLeft == null ? '' : ' · $adsLeft left today'}',
            value: CoinGateChoice.watchAd,
          ),
        const CoinGateOption(label: 'Upgrade to Pro', value: CoinGateChoice.upgrade, outlined: true),
      ],
    );
    return choice ?? CoinGateChoice.cancel;
  }

  String? get _ledgerLabel {
    final String title = widget.wallpaperTitle?.trim() ?? '';
    if (title.isNotEmpty) return title;
    final String creator = widget.creatorName?.trim() ?? '';
    return creator.isEmpty ? null : 'Wallpaper by $creator';
  }

  Future<CoinGateResult> _gatedDownload() {
    final String contentId = widget.contentId?.trim() ?? '';
    return CoinGate.forContext(context).run(
      CoinGateSpec(
        action: _downloadSpendAction,
        reason: contentId.isEmpty ? null : 'content_$contentId',
        label: _ledgerLabel,
        pendingDownloadLink: widget.link?.trim(),
        tags: const CoinGateTags(
          spend: 'coins.download.spend',
          retrySpend: 'coins.download.watch_and_download.spend',
          ad: 'coins.download.watch_and_download.rewarded_ad',
          insufficient: 'coins.download.insufficient_balance_nudge',
        ),
        upsellSource: 'download_watch_and_download_rewarded_ad',
        upgradeSource: 'download_low_balance_upgrade',
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
          _failureReason = isPhotosPermissionDenied(result.errorCode) ? 'permission_denied' : 'save_failed';
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
          _failureReason = isPhotosPermissionDenied(result.errorCode) ? 'permission_denied' : 'enqueue_failed';
          if (isPhotosPermissionDenied(result.errorCode)) {
            if (mounted) showPhotosPermissionDenied(context);
          } else {
            toasts.error(result.message ?? "Couldn't download! Please retry.");
          }
          return false;
        }
      }
    } on PlatformException catch (e) {
      _failureReason = 'platform_error';
      if (e.code == 'channel-error') {
        logger.w('Download channel unavailable (native side not registered)', error: e);
      } else {
        logger.e('Download failed', error: e);
      }
      toasts.error("Couldn't download! Please retry.");
      return false;
    } catch (e, stackTrace) {
      _failureReason = 'unexpected';
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

    if (mounted) setState(() => _saved = true);
    final String contentId = widget.contentId?.trim() ?? '';
    if (contentId.isNotEmpty) {
      try {
        unawaited(getIt<RecordWallpaperActionUseCase>()(contentId, WallpaperAction.download));
      } catch (e, stackTrace) {
        logger.w('Download action record failed after media was saved', error: e, stackTrace: stackTrace);
      }
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
    if (mounted) {
      try {
        unawaited(RatePromptService.instance.maybePrompt(context, RatePromptTrigger.download));
      } catch (e, stackTrace) {
        logger.w('Rate prompt after download failed', error: e, stackTrace: stackTrace);
      }
    }
    return true;
  }
}
