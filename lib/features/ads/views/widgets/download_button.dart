import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
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
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
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
    this.variant,
    this.primary = false,
    this.labelled = false,
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

  /// Saves a changed copy, such as a colour variation, in place of [link]. `variant.prepare` runs once per tap, after
  /// the "already in Downloads" check and before the coin gate. If it throws, the user is told and nothing is charged.
  /// The recovery marker, the "already in Downloads" check and the saved file name use `variant.identityOf(link)`, so
  /// each variation is its own purchase.
  final DownloadVariant? variant;

  /// Draws a compact accent button with a label instead of a round icon button.
  final bool primary;

  /// Shows a caption under the round icon button.
  final bool labelled;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

enum _SavedChoice { open, again }

enum _GuestProChoice { signIn, pro }

class _DownloadTap {
  const _DownloadTap({
    required this.link,
    required this.identity,
    required this.isPremiumContent,
    required this.contentId,
    required this.sourceContext,
    required this.wallpaperTitle,
    required this.creatorName,
    required this.onDownloaded,
  });

  final String link;
  final String identity;
  final bool isPremiumContent;
  final String? contentId;
  final String? sourceContext;
  final String? wallpaperTitle;
  final String? creatorName;
  final VoidCallback? onDownloaded;
}

class _DownloadButtonState extends State<DownloadButton> {
  bool isLoading = false;
  bool _saved = false;
  String? _preparedSource;
  _DownloadTap? _activeTap;

  /// The ledger id of the payment this tap made, or null when it paid nothing. Only a tap that paid marks an entry,
  /// and only its own, so no other tap or button of the same wallpaper can settle it. The coin gate settles the entry
  /// itself once the tap ends.
  String? _paidTxId;
  String? _failureReason;
  String _failureStage = 'download';

  CoinSpendAction get _downloadSpendAction =>
      widget.isPremiumContent ? CoinSpendAction.premiumWallpaperDownload : CoinSpendAction.wallpaperDownload;

  _DownloadTap get _tap => _activeTap!;

  CoinSpendAction get _tapSpendAction =>
      _tap.isPremiumContent ? CoinSpendAction.premiumWallpaperDownload : CoinSpendAction.wallpaperDownload;

  @override
  void initState() {
    super.initState();
    _saved = _isSaved(_currentIdentity);
  }

  @override
  void didUpdateWidget(DownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link != widget.link || oldWidget.variant?.key != widget.variant?.key) {
      _saved = _isSaved(_currentIdentity);
    }
  }

  String? get _currentIdentity {
    final String link = widget.link?.trim() ?? '';
    return link.isEmpty ? null : widget.variant?.identityOf(link) ?? link;
  }

  bool _isSaved(String? identity) {
    final String trimmed = identity?.trim() ?? '';
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
    final String? label = widget.label;
    if (label == null && !widget.primary) {
      return CircularMenuButton(
        label: 'Download',
        caption: widget.labelled ? 'Download' : null,
        onTap: _handleTap,
        isLoading: isLoading,
        child: const Icon(JamIcons.download),
      );
    }
    final String text;
    final String semantics;
    if (label == null) {
      text = 'Download';
      semantics = 'Download';
    } else if (_saved) {
      text = 'Saved';
      semantics = 'Saved. Already in Downloads';
    } else if (app_state.prismUser.premium) {
      text = 'Free with Pro';
      semantics = '$label. Free with Pro';
    } else if (_isGuest) {
      text = label;
      semantics = label;
    } else {
      final int cost = _downloadSpendAction.cost();
      text = '$label · $cost';
      semantics = '$label. Costs $cost coins';
    }
    if (widget.primary) {
      return Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        onTap: _handleTap,
        child: PrismButton(
          label: text,
          size: PrismButtonSize.compact,
          loading: isLoading,
          onPressed: () => _handleTap(playTapHaptic: false),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: PrimaryActionPill(icon: JamIcons.download, label: text, semanticLabel: semantics, isLoading: isLoading),
    );
  }

  Future<void> _handleTap({bool playTapHaptic = true}) async {
    if (isLoading) {
      toasts.error('Wait for download to complete!');
      return;
    }

    final String link = widget.link?.trim() ?? '';
    if (link.isEmpty) {
      toasts.error('No download link available.');
      return;
    }
    if (playTapHaptic) PrismHaptics.tap();

    if (mounted) {
      setState(() => isLoading = true);
    }
    try {
      _preparedSource = null;
      final DownloadVariant? variant = widget.variant;
      final _DownloadTap tap = _DownloadTap(
        link: link,
        identity: variant?.identityOf(link) ?? link,
        isPremiumContent: widget.isPremiumContent,
        contentId: widget.contentId,
        sourceContext: widget.sourceContext,
        wallpaperTitle: widget.wallpaperTitle,
        creatorName: widget.creatorName,
        onDownloaded: widget.onDownloaded,
      );
      _activeTap = tap;
      _paidTxId = null;
      if (!await _confirmDownloadAgain(tap.identity)) return;
      if (variant != null) {
        _preparedSource = await runPrepareSource(variant.prepare);
        if (_preparedSource == null || !mounted) return;
      }
      _failureReason = null;
      _failureStage = 'download';
      _track(DownloadAttemptEvent(source: _sourceLabel, premium: tap.isPremiumContent));
      if (_isGuest) {
        await _runGuestFlow();
        return;
      }
      final CoinGateResult result = await _gatedDownload();
      _trackGateResult(result);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String get _sourceLabel {
    final String source = _tap.sourceContext?.trim() ?? '';
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
  Future<bool> _confirmDownloadAgain(String identity) async {
    if (!_isSaved(identity) || !await _fileStillInDownloads(identity) || !mounted) return true;
    final bool free = app_state.prismUser.premium || _isGuest;
    final int cost = _tapSpendAction.cost();
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

  /// True when the Downloads list still holds a file with this identity's name. False when it cannot tell.
  Future<bool> _fileStillInDownloads(String identity) async {
    try {
      final DownloadItemsResult result = await PrismMediaHostApi().listDownloads();
      if (!result.success) return false;
      final String base = downloadBaseName(identity);
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
    if (_tap.isPremiumContent) {
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
    await showPrismSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _GuestAdGateSheet(
        adsAllowed: adsAllowed,
        onBuyPremium: () {
          Navigator.of(sheetContext).pop();
          PaywallOrchestrator.instance.presentOrRequireSignIn(
            context,
            placement: PaywallPlacement.mainUpsell,
            source: 'download_guest_buy_premium',
          );
        },
        onWatched: () => pendingDownload = _performDownload(),
      ),
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
            label: '${watchAdOptionLabel()}${adsLeft == null ? '' : ' · $adsLeft left today'}',
            value: CoinGateChoice.watchAd,
          ),
        const CoinGateOption(label: 'Upgrade to Pro', value: CoinGateChoice.upgrade, outlined: true),
      ],
    );
    return choice ?? CoinGateChoice.cancel;
  }

  String? get _ledgerLabel {
    final String title = _tap.wallpaperTitle?.trim() ?? '';
    if (title.isNotEmpty) return title;
    final String creator = _tap.creatorName?.trim() ?? '';
    return creator.isEmpty ? null : 'Wallpaper by $creator';
  }

  Future<CoinGateResult> _gatedDownload() {
    final String contentId = _tap.contentId?.trim() ?? '';
    return CoinGate.forContext(context).run(
      CoinGateSpec(
        action: _tapSpendAction,
        reason: contentId.isEmpty ? null : 'content_$contentId',
        label: _ledgerLabel,
        pendingDownloadLink: _tap.identity,
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
        onPaid: (String txId) => _paidTxId = txId,
        isMounted: () => mounted,
        perform: _performDownload,
        choose: _chooseLowBalanceAction,
        onWatchChosen: () => CoinsService.instance.logWatchAndDownloadUsed(
          isPremiumContent: _tap.isPremiumContent,
          sourceTag: 'coins.download.watch_and_download',
        ),
      ),
    );
  }

  Future<bool> _performDownload() async {
    final _DownloadTap tap = _tap;
    final String link = tap.link;
    final String? sourceContext = tap.sourceContext;
    final bool premiumContent = tap.isPremiumContent;
    final VoidCallback? onDownloaded = tap.onDownloaded;
    if (link.isEmpty) {
      toasts.error('No download link available.');
      return false;
    }
    final String saveLink = _preparedSource ?? link;
    final bool prepared = _preparedSource != null;

    try {
      final Uri? source = Uri.tryParse(saveLink);
      if (!prepared && (saveLink.startsWith('/') || source?.scheme == 'file')) {
        final SaveMediaRequest request = SaveMediaRequest(
          link: saveLink,
          isLocalFile: true,
          kind: SaveMediaKind.wallpaper,
        );
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
        final DownloadRequest request = DownloadRequest(
          link: saveLink,
          filenameWithoutExtension: downloadBaseName(tap.identity),
          isLocalFile: prepared,
        );
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

    final String? paidTxId = _paidTxId;
    if (paidTxId != null) await CoinsService.instance.markPendingDownloadSaved(paidTxId);

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

    if (mounted && tap.identity == _currentIdentity) setState(() => _saved = true);
    final String contentId = tap.contentId?.trim() ?? '';
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

/// The sheet a signed-out user sees before a download: watch an ad or go Premium.
class _GuestAdGateSheet extends StatefulWidget {
  const _GuestAdGateSheet({required this.adsAllowed, required this.onBuyPremium, required this.onWatched});

  final bool adsAllowed;
  final VoidCallback onBuyPremium;

  /// Runs after the ad is watched and the sheet has closed.
  final Future<bool> Function() onWatched;

  @override
  State<_GuestAdGateSheet> createState() => _GuestAdGateSheetState();
}

class _GuestAdGateSheetState extends State<_GuestAdGateSheet> {
  bool _watching = false;

  Future<void> _watch() async {
    setState(() => _watching = true);
    final RewardedAdResult watched = await watchRewardedAdResult(context.read<AdsBloc>());
    if (mounted) setState(() => _watching = false);
    if (!watched.earned) {
      toasts.error(adFailureMessage(watched.failure));
      return;
    }
    if (!mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    final Future<bool> Function() onWatched = widget.onWatched;
    if (navigator.canPop()) navigator.pop();
    await onWatched();
  }

  @override
  Widget build(BuildContext context) {
    return PrismSheetBody(
      title: 'Download this wallpaper',
      message: widget.adsAllowed
          ? 'Watch a small video ad to download this wallpaper.'
          : 'Watch a small video ad to download this wallpaper. Ads are off. Change this in Settings > Privacy.',
      actions: <Widget>[
        if (widget.adsAllowed) PrismButton(label: 'Watch ad', expand: true, loading: _watching, onPressed: _watch),
        PrismButton(
          label: 'Buy premium',
          expand: true,
          variant: widget.adsAllowed ? PrismButtonVariant.tonal : PrismButtonVariant.primary,
          onPressed: _watching ? null : widget.onBuyPremium,
        ),
      ],
    );
  }
}
