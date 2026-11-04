import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class DownloadButton extends StatefulWidget {
  const DownloadButton({
    required this.link,
    this.isPremiumContent = false,
    this.contentId,
    this.wallpaperSource,
    this.indexSource,
    this.savedIdentity,
    this.depthTier,
    this.spatialTier,
    this.sourceContext,
    this.requestId,
    this.onDownloaded,
    this.label,
    this.wallpaperTitle,
    this.creatorName,
    this.onOpenDownloads,
    this.variant,
    this.desktop,
    this.set,
    this.primary = false,
    this.expand = false,
    this.labelled = false,
    this.duoReveal = false,
    super.key,
  }) : assert(set == null || (variant == null && desktop == null), 'A set saves the original wall.');

  final String? link;
  final bool isPremiumContent;
  final String? contentId;
  final WallpaperSource? wallpaperSource;

  /// Canonical identity of a reopened local file. Never used to authorize remote originals.
  final WallpaperSource? indexSource;

  /// Stable indexed identity when reopening an existing local copy, including its saved variation.
  final String? savedIdentity;

  /// Adds the Depth Effect step to what iOS users see after the save.
  final WallDepthTier? depthTier;

  /// Adds the Spatial Scene step to what iOS users see after the save.
  final WallSpatialTier? spatialTier;
  final String? sourceContext;
  final String? requestId;
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

  /// Saves the desktop version of the wall in place of the phone original. It has its own grant and its own name in
  /// Downloads.
  final WallDesktopVariant? desktop;

  /// Saves the wall with more files, such as a watch set, in one gate run. The tap counts as one download, plus one for
  /// the set's desktop version.
  final DownloadSet? set;

  /// Draws a compact accent button with a label instead of a round icon button.
  final bool primary;

  /// Draws the [primary] button full width at sheet size.
  final bool expand;

  /// Shows a caption under the round icon button.
  final bool labelled;
  final bool duoReveal;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

enum _SavedChoice { open, again }

typedef _DownloadConfirmation = ({bool proceed, File? freeLocalCopy});

class _DownloadTap {
  const _DownloadTap({
    required this.requestId,
    required this.operationId,
    required this.link,
    required this.identity,
    required this.isPremiumContent,
    required this.contentId,
    required this.wallpaperSource,
    required this.indexSource,
    required this.depthTier,
    required this.spatialTier,
    required this.sourceContext,
    required this.wallpaperTitle,
    required this.creatorName,
    required this.onDownloaded,
    required this.ownerId,
    required this.isGuest,
    required this.duoReveal,
    required this.desktop,
    required this.set,
    required this.fileIdentity,
  });

  final String link;
  final String operationId;
  final String? requestId;
  final String identity;
  final bool isPremiumContent;
  final String? contentId;
  final WallpaperSource? wallpaperSource;
  final WallpaperSource? indexSource;
  final WallDepthTier? depthTier;
  final WallSpatialTier? spatialTier;
  final String? sourceContext;
  final String? wallpaperTitle;
  final String? creatorName;
  final VoidCallback? onDownloaded;
  final String ownerId;
  final bool isGuest;
  final bool duoReveal;
  final WallDesktopVariant? desktop;
  final DownloadSet? set;

  /// The name the main file is saved under. For a set it is the wall's own name, and [identity] names the set.
  final String fileIdentity;
}

class _DownloadButtonState extends State<DownloadButton> {
  bool isLoading = false;
  bool _saved = false;
  bool _signInPending = false;
  int _awardCoins = 0;
  final Set<String> _shownReceipts = <String>{};
  late String _savedOwner;
  String? _preparedSource;
  String? _authorizedSource;

  /// The desktop version a set's gate run was granted. Null when the set has none or the grant was refused.
  String? _authorizedDesktop;

  /// Temporary files the set of this tap made. The tap deletes them when it ends.
  Map<String, String> _setFiles = const <String, String>{};
  late _DownloadTap _activeTap;
  bool _attemptStarted = false;
  bool _resultTracked = false;

  /// The ledger id of the payment this tap made, or null when it paid nothing. Only a tap that paid marks an entry,
  /// and only its own, so no other tap or button of the same wallpaper can settle it. The coin gate settles the entry
  /// itself once the tap ends.
  String? _paidTxId;
  String? _failureReason;
  String _failureStage = 'download';

  CoinSpendAction get _downloadSpendAction =>
      widget.isPremiumContent ? CoinSpendAction.premiumWallpaperDownload : CoinSpendAction.wallpaperDownload;

  _DownloadTap get _tap => _activeTap;

  CoinSpendAction get _tapSpendAction =>
      _tap.isPremiumContent ? CoinSpendAction.premiumWallpaperDownload : CoinSpendAction.wallpaperDownload;

  @override
  void initState() {
    super.initState();
    _savedOwner = app_state.prismUser.id;
    _saved = _isSaved(_currentIdentity);
  }

  @override
  void didUpdateWidget(DownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link != widget.link ||
        oldWidget.contentId != widget.contentId ||
        oldWidget.wallpaperSource != widget.wallpaperSource ||
        oldWidget.variant?.key != widget.variant?.key ||
        oldWidget.desktop != widget.desktop ||
        oldWidget.set?.key != widget.set?.key ||
        oldWidget.set?.desktop != widget.set?.desktop ||
        oldWidget.savedIdentity != widget.savedIdentity ||
        oldWidget.indexSource != widget.indexSource ||
        _savedOwner != app_state.prismUser.id) {
      _savedOwner = app_state.prismUser.id;
      _awardCoins = 0;
      _saved = _isSaved(_currentIdentity);
    }
  }

  String? get _currentIdentity {
    final String link = widget.link?.trim() ?? '';
    if (link.isEmpty && (widget.contentId?.trim().isEmpty ?? true)) return null;
    final original = _originalIdentity(link, widget.contentId);
    final WallDesktopVariant? desktop = widget.desktop;
    final DownloadSet? set = widget.set;
    return widget.savedIdentity ??
        (set == null ? null : DownloadVariant.identityFor(original, set.key)) ??
        (desktop == null ? null : DownloadVariant.identityFor(original, 'desktop-${desktop.version}')) ??
        widget.variant?.identityOf(original) ??
        original;
  }

  String _originalIdentity(String link, String? id) => link.isEmpty ? '$id.jpg' : link;

  bool _isSaved(String? identity) {
    final String trimmed = identity?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    try {
      final String? id = widget.contentId?.trim();
      final WallpaperSource? source = widget.indexSource ?? widget.wallpaperSource;
      if (source != null && (id == null || id.isEmpty)) return false;
      if (id != null && id.isNotEmpty && source != null && getIt.isRegistered<DownloadedWallIndex>()) {
        return getIt<DownloadedWallIndex>().hasAcquired(link: trimmed, id: id, source: source);
      }
      return CoinsService.instance.isLinkDownloaded(trimmed);
    } catch (_) {
      return false;
    }
  }

  /// Free for a signed-in user without Pro: an active pass on a premium wall, or a grace download on a standard one.
  bool _downloadIsFree(bool premiumContent) =>
      premiumContent ? CoinsService.instance.premiumContentUnlocked : CoinsService.instance.graceDownloadsLeft > 0;

  bool get _isGuest => !app_state.prismUser.premium && !app_state.prismUser.loggedIn;

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);
    if (!DailyMomentConfig.enabled || _awardCoins <= 0 || _savedOwner != app_state.prismUser.id) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        Text(
          context.l10n.economyCoinsEarned(_awardCoins),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ],
    );
  }

  Widget _buildButton(BuildContext context) {
    final String? label = widget.label;
    if (label == null && !widget.primary) {
      return CircularMenuButton(
        label: context.l10n.economyDownload,
        caption: widget.labelled ? context.l10n.economyDownload : null,
        onTap: _handleTap,
        isLoading: isLoading,
        child: const Icon(JamIcons.download),
      );
    }
    final String text;
    final String semantics;
    if (label == null) {
      text = context.l10n.economyDownload;
      semantics = context.l10n.economyDownload;
    } else if (_saved && _savedOwner == app_state.prismUser.id) {
      text = context.l10n.economyDownloadSaved;
      semantics = context.l10n.economyDownloadSavedInDownloads;
    } else if (app_state.prismUser.premium) {
      text = context.l10n.economyDownloadFreeWithPro;
      semantics = context.l10n.economyDownloadFreeWithProSemantics(label);
    } else if (_isGuest) {
      text = label;
      semantics = label;
    } else if (OriginalAccessService.isUnlockedDropUrl(
      widget.link?.trim() ?? '',
      widget.contentId,
      widget.wallpaperSource,
    )) {
      text = context.l10n.economyDownloadFreeFor(label);
      semantics = context.l10n.economyDownloadFreeOwnedSemantics(label);
    } else if (_downloadIsFree(widget.isPremiumContent) &&
        (widget.isPremiumContent || CoinsService.instance.graceDownloadsLeft >= (widget.set?.paidItems ?? 1))) {
      final int left = CoinsService.instance.graceDownloadsLeft;
      text = widget.isPremiumContent
          ? context.l10n.economyDownloadFreeFor(label)
          : context.l10n.economyDownloadFreeLeftFor(label, left);
      semantics = widget.isPremiumContent
          ? context.l10n.economyDownloadFreeWithPassSemantics(label)
          : context.l10n.economyDownloadFreeDownloadsLeftSemantics(label, left);
    } else {
      final int cost = _downloadSpendAction.cost() * (widget.set?.paidItems ?? 1);
      text = context.l10n.economyDownloadCost(label, cost);
      semantics = context.l10n.economyDownloadCostSemantics(label, cost);
    }
    if (widget.primary) {
      return Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        onTap: _handleTap,
        child: PrismButton(
          label: text,
          size: widget.expand ? PrismButtonSize.large : PrismButtonSize.compact,
          expand: widget.expand,
          maxLines: widget.expand ? 3 : 1,
          loading: isLoading,
          onPressed: () => _handleTap(playTapHaptic: false),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: PrimaryActionPill(label: text, semanticLabel: semantics, isLoading: isLoading),
    );
  }

  Future<void> _recordAward(String contentId, _DownloadTap tap) async {
    if (!_ownerStillMatches(tap)) return;
    try {
      final result = await getIt<RecordWallpaperActionUseCase>()(contentId, WallpaperAction.download);
      final receipt = result.data;
      if (mounted &&
          tap.identity == _currentIdentity &&
          tap.ownerId == app_state.prismUser.id &&
          receipt != null &&
          receipt.coins > 0 &&
          receipt.receiptId != null &&
          _shownReceipts.add(receipt.receiptId!)) {
        setState(() => _awardCoins = receipt.coins);
        unawaited(CoinsService.instance.refreshBalance().catchError((Object _) => app_state.prismUser.coins));
      }
    } catch (error, stackTrace) {
      logger.w('Download action record failed after media was saved', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _handleTap({bool playTapHaptic = true}) async {
    final AppLocalizations l10n = context.l10n;
    if (isLoading) {
      toasts.error(context.l10n.economyDownloadWaitForCurrent);
      return;
    }
    if (_signInPending) return;
    _signInPending = true;
    late final bool signedIn;
    try {
      signedIn = await requireSignedInAction(context);
    } finally {
      _signInPending = false;
    }
    if (!signedIn || !mounted) return;

    final String link = widget.link?.trim() ?? '';
    if (link.isEmpty && widget.wallpaperSource != WallpaperSource.prism) {
      toasts.error(context.l10n.economyDownloadLinkUnavailable);
      return;
    }
    if (playTapHaptic) PrismHaptics.tap();
    final DownloadSet? busySet = widget.set;

    if (mounted) {
      setState(() {
        isLoading = true;
        _awardCoins = 0;
      });
    }
    try {
      busySet?.onBusyChanged?.call(true);
      _preparedSource = null;
      _authorizedDesktop = null;
      final DownloadVariant? variant = widget.variant;
      final _DownloadTap tap = _DownloadTap(
        requestId: widget.requestId,
        operationId: AnalyticsCorrelation.newId(),
        link: link,
        identity: _currentIdentity ?? _originalIdentity(link, widget.contentId),
        isPremiumContent: widget.isPremiumContent,
        contentId: widget.contentId,
        wallpaperSource: widget.wallpaperSource,
        indexSource: widget.indexSource ?? widget.wallpaperSource,
        depthTier: widget.depthTier,
        spatialTier: widget.spatialTier,
        sourceContext: widget.sourceContext,
        wallpaperTitle: widget.wallpaperTitle,
        creatorName: widget.creatorName,
        onDownloaded: widget.onDownloaded,
        ownerId: app_state.prismUser.id,
        isGuest: _isGuest,
        duoReveal: widget.duoReveal,
        desktop: widget.desktop,
        set: widget.set,
        fileIdentity: widget.set == null
            ? _currentIdentity ?? _originalIdentity(link, widget.contentId)
            : _originalIdentity(link, widget.contentId),
      );
      _activeTap = tap;
      _attemptStarted = false;
      _resultTracked = false;
      _paidTxId = null;
      final _DownloadConfirmation confirmation = await _confirmDownloadAgain(tap);
      if (!confirmation.proceed) return;
      if (!_ownerStillMatches(tap)) {
        _cancelAfterAccountSwitch();
        return;
      }
      _failureReason = null;
      _failureStage = 'download';
      _authorizedSource = null;
      _attemptStarted = true;
      _track(
        DownloadAttemptEvent(
          source: _sourceLabel,
          premium: tap.isPremiumContent,
          operationId: tap.operationId,
          itemId: tap.contentId,
          provider: tap.wallpaperSource?.name,
          requestId: tap.requestId,
        ),
      );
      final bool serverAccess =
          OriginalAccessService.requiresGrant(
            tap.link,
            tap.contentId,
            tap.wallpaperSource,
            desktop: tap.desktop != null,
          ) ||
          ((tap.wallpaperSource == null ||
                  tap.wallpaperSource == WallpaperSource.unknown ||
                  tap.wallpaperSource == WallpaperSource.downloaded) &&
              isValidNetworkUrl(tap.link));
      if (serverAccess) {
        _authorizedSource = (confirmation.freeLocalCopy ?? await _previouslyAcquiredLocalOriginal(tap))?.path;
        if (!_ownerStillMatches(tap)) {
          _cancelAfterAccountSwitch();
          return;
        }
        final result = await _gatedDownload(originalAccess: true, variant: variant);
        _trackGateResult(result);
        return;
      }
      if (variant != null) {
        _preparedSource = await runPrepareSource(
          variant.prepareAuthorized == null
              ? variant.prepare
              : () => variant.prepareAuthorized!(_authorizedSource ?? tap.link),
          l10n: l10n,
        );
        if (!_ownerStillMatches(tap)) {
          _cancelAfterAccountSwitch();
          return;
        }
        if (_preparedSource == null || !mounted) {
          _track(
            DownloadResultEvent(
              result: _preparedSource == null ? 'failed' : 'cancelled',
              reason: _preparedSource == null ? 'preparation_failed' : 'screen_disposed',
              stage: 'prepare',
            ),
          );
          return;
        }
      }
      if (!_ownerStillMatches(tap)) {
        _cancelAfterAccountSwitch();
        return;
      }
      final String? contentId = tap.contentId?.trim();
      final WallpaperSource? wallpaperSource = tap.wallpaperSource;
      if (contentId != null &&
          contentId.isNotEmpty &&
          wallpaperSource != null &&
          BundledWallpapers.isStarterIdentity(contentId, wallpaperSource)) {
        final File? starter;
        try {
          starter = await BundledWallpapers.localFileForStarter(contentId, wallpaperSource);
        } catch (error, stackTrace) {
          logger.w('Could not resolve bundled starter wallpaper', error: error, stackTrace: stackTrace);
          _track(const DownloadResultEvent(result: 'failed', reason: 'starter_source_failed', stage: 'prepare'));
          toasts.error(l10n.economyAiDownloadFailed);
          unawaited(RatePromptService.instance.recordFailure());
          return;
        }
        if (starter == null) {
          _track(const DownloadResultEvent(result: 'failed', reason: 'starter_source_unavailable', stage: 'prepare'));
          toasts.error(l10n.economyAiDownloadFailed);
          unawaited(RatePromptService.instance.recordFailure());
          return;
        }
        if (!_ownerStillMatches(tap)) {
          _cancelAfterAccountSwitch();
          return;
        }
        final bool saved = await _performDownload(cachedOriginalForRestore: starter);
        _track(
          DownloadResultEvent(
            result: saved ? 'success' : 'failed',
            reason: saved ? null : _failureReason ?? 'starter_save_failed',
            stage: saved ? 'download' : _failureStage,
          ),
        );
        return;
      }
      final File? freeLocalCopy = confirmation.freeLocalCopy ?? await _previouslyAcquiredLocalOriginal(tap);
      if (!_ownerStillMatches(tap)) {
        _cancelAfterAccountSwitch();
        return;
      }
      if (freeLocalCopy != null) {
        final bool saved = await _performDownload(cachedOriginalForRestore: freeLocalCopy);
        _track(
          DownloadResultEvent(
            result: saved ? 'success' : 'failed',
            reason: saved ? null : _failureReason ?? 'restore_failed',
            stage: saved ? 'download' : _failureStage,
          ),
        );
        return;
      }
      // The Drop unlock already paid for this wall.
      if (OriginalAccessService.isUnlockedDropUrl(tap.link, tap.contentId, tap.wallpaperSource)) {
        final bool saved = await _performDownload();
        _track(
          DownloadResultEvent(
            result: saved ? 'success' : 'failed',
            reason: saved ? null : _failureReason ?? 'drop_save_failed',
            stage: saved ? 'download' : _failureStage,
          ),
        );
        return;
      }
      final CoinGateResult result = await _gatedDownload();
      _trackGateResult(result);
    } catch (error, stackTrace) {
      logger.w('Could not acquire wallpaper', error: error, stackTrace: stackTrace);
      if (mounted) toasts.error(l10n.economyAiDownloadFailed);
    } finally {
      await _discardSetFiles();
      busySet?.onBusyChanged?.call(false);
      if (_attemptStarted && !_resultTracked) {
        _track(
          DownloadResultEvent(result: 'failed', reason: _failureReason ?? 'preparation_failed', stage: _failureStage),
        );
      }
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
    if (event is DownloadResultEvent) {
      if (!_attemptStarted || _resultTracked) return;
      _resultTracked = true;
      event = DownloadResultEvent(
        result: event.result,
        reason: event.reason,
        stage: event.stage,
        operationId: _tap.operationId,
        requestId: _tap.requestId,
        itemId: _tap.contentId,
        provider: _tap.wallpaperSource?.name,
        source: _sourceLabel,
      );
    }
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
  Future<_DownloadConfirmation> _confirmDownloadAgain(_DownloadTap tap) async {
    if (!await _fileStillInDownloads(tap.identity) || !mounted) {
      return (proceed: true, freeLocalCopy: null);
    }
    final File? localOriginal = await _previouslyAcquiredLocalOriginal(tap);
    if (!mounted) return (proceed: false, freeLocalCopy: null);
    final bool free =
        app_state.prismUser.premium ||
        _isGuest ||
        (_downloadIsFree(tap.isPremiumContent) &&
            (tap.isPremiumContent || CoinsService.instance.graceDownloadsLeft >= (tap.set?.paidItems ?? 1))) ||
        OriginalAccessService.isUnlockedDropUrl(tap.link, tap.contentId, tap.wallpaperSource);
    final int cost = _tapSpendAction.cost() * (tap.set?.paidItems ?? 1);
    final _SavedChoice? choice = await showCoinGateSheet<_SavedChoice>(
      context,
      title: context.l10n.economyDownloadAlreadyInDownloads,
      cost: 0,
      message: (_) => context.l10n.economyDownloadSavedBefore,
      options: <CoinGateOption<_SavedChoice>>[
        CoinGateOption(label: context.l10n.economyOpen, value: _SavedChoice.open),
        CoinGateOption(
          label: localOriginal != null
              ? context.l10n.economyDownloadSaveLocalCopy
              : free
              ? context.l10n.economyDownloadAgain
              : context.l10n.economyDownloadAgainCost(cost),
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
    return (proceed: choice == _SavedChoice.again, freeLocalCopy: choice == _SavedChoice.again ? localOriginal : null);
  }

  bool _ownerStillMatches(_DownloadTap tap) => app_state.prismUser.loggedIn && tap.ownerId == app_state.prismUser.id;

  void _cancelAfterAccountSwitch() {
    _track(const DownloadResultEvent(result: 'cancelled', reason: 'account_changed', stage: 'gate'));
    if (mounted) toasts.error(context.l10n.economyDownloadAccountChanged);
  }

  Future<File?> _previouslyAcquiredLocalOriginal(_DownloadTap tap) async {
    final String? id = tap.contentId?.trim();
    final WallpaperSource? source = tap.wallpaperSource;
    if (tap.isGuest ||
        !_ownerStillMatches(tap) ||
        tap.identity != _originalIdentity(tap.link, tap.contentId) ||
        id == null ||
        id.isEmpty ||
        source == null) {
      return null;
    }
    if (!getIt.isRegistered<DownloadedWallIndex>()) return null;
    final DownloadedWallIndex index = getIt<DownloadedWallIndex>();
    final original = _originalIdentity(tap.link, id);
    if (!index.hasAcquired(link: original, id: id, source: source)) return null;
    try {
      final OfflineAssetStore store = OfflineAssetStore.instance;
      final File? retainedOrCached = await store.lookup(original);
      if (retainedOrCached != null) return retainedOrCached;
      final File? downloaded = await index.localFileFor(link: original, id: id, source: source);
      return downloaded == null ? null : await store.lookup(downloaded.path);
    } catch (error, stackTrace) {
      logger.w('Could not inspect a previously acquired local original', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// True when the Downloads list still holds a file with this identity's name. False when it cannot tell.
  Future<bool> _fileStillInDownloads(String identity) async {
    final DownloadedWallIndex? index = getIt.isRegistered<DownloadedWallIndex>() ? getIt<DownloadedWallIndex>() : null;
    if (index != null) {
      final String? id = _tap.contentId?.trim();
      final WallpaperSource? source = _tap.indexSource;
      final File? exactFile = id != null && id.isNotEmpty && source != null
          ? await index.localFileFor(link: identity, id: id, source: source)
          : await index.localFileForLink(identity);
      return exactFile != null;
    }
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

  Future<CoinGateChoice> _chooseLowBalanceAction(CoinGatePrompt prompt) async {
    final int missing = prompt.missing;
    final int? adsLeft = prompt.adsRemaining;
    final String adState = !prompt.adsAllowed ? 'disabled' : (adsLeft != null && adsLeft <= 0 ? 'limit' : 'none');
    final CoinGateChoice? choice = await showCoinGateSheet<CoinGateChoice>(
      context,
      title: context.l10n.economyNotEnoughCoins,
      cost: prompt.cost,
      message: (int sheetMissing) {
        final int adReward = CoinsService.instance.adsRewardNow;
        return context.l10n.economyDownloadCoinsNeeded(
          sheetMissing > 0 ? sheetMissing : missing,
          adReward,
          prompt.canWatchAd ? 'true' : 'false',
          adState,
        );
      },
      options: <CoinGateOption<CoinGateChoice>>[
        if (prompt.canWatchAd)
          CoinGateOption(
            label: adsLeft == null
                ? watchAdOptionLabel(context.l10n)
                : context.l10n.economyWatchVideoRewardAdsLeft(adsLeft),
            value: CoinGateChoice.watchAd,
          ),
        CoinGateOption(label: context.l10n.economyUpgradeToPro, value: CoinGateChoice.upgrade, outlined: true),
      ],
    );
    return choice ?? CoinGateChoice.cancel;
  }

  String? get _ledgerLabel {
    final String title = _tap.wallpaperTitle?.trim() ?? '';
    if (title.isNotEmpty) return title;
    final String creator = _tap.creatorName?.trim() ?? '';
    return creator.isEmpty ? null : context.l10n.wallpaperByCreator(creator);
  }

  Future<CoinGateResult> _gatedDownload({bool originalAccess = false, DownloadVariant? variant}) async {
    final String contentId = _tap.contentId?.trim() ?? '';
    final WallDesktopVariant? setDesktop = originalAccess ? _tap.set?.desktop : null;
    int? phoneCoins;
    int? setDesktopCoins;
    int? serverRequiredCoins;
    int? serverBalance;
    if (originalAccess && _authorizedSource == null) {
      final quote = await OriginalAccessService.instance.quote(
        wallpaperId: contentId,
        action: OriginalAccessAction.download,
        desktop: _tap.desktop != null,
        desktopVersion: _tap.desktop?.version,
      );
      phoneCoins = serverRequiredCoins = quote.requiredCoins;
      serverBalance = quote.currentBalance;
      if (!mounted || !_ownerStillMatches(_tap)) return CoinGateResult.cancelled;
      CoinsService.instance.applyServerBalance(quote.currentBalance, ownerId: _tap.ownerId);
    }
    if (setDesktop != null) {
      final quote = await OriginalAccessService.instance.quote(
        wallpaperId: contentId,
        action: OriginalAccessAction.download,
        desktop: true,
        desktopVersion: setDesktop.version,
      );
      setDesktopCoins = quote.requiredCoins;
      serverRequiredCoins = (serverRequiredCoins ?? 0) + quote.requiredCoins;
      serverBalance = quote.currentBalance;
      if (!mounted || !_ownerStillMatches(_tap)) return CoinGateResult.cancelled;
      CoinsService.instance.applyServerBalance(quote.currentBalance, ownerId: _tap.ownerId);
    }
    return CoinGate.forContext(context).run(
      CoinGateSpec(
        premiumBypass: !originalAccess,
        refundOnFailure: !originalAccess,
        confirmFirst: originalAccess && (serverRequiredCoins ?? 0) > 0,
        spend: !originalAccess
            ? null
            : (_) async {
                if (!_ownerStillMatches(_tap)) throw StateError('Download account changed');
                final balance = CoinsService.instance.balanceNotifier.value;
                if (setDesktop != null && balance < (serverRequiredCoins ?? 0)) {
                  serverBalance = balance;
                  return CoinMutationResult(
                    success: false,
                    changed: false,
                    previousBalance: balance,
                    currentBalance: balance,
                    delta: 0,
                    insufficientBalance: true,
                  );
                }
                try {
                  _authorizedSource ??= await OriginalAccessService.instance.resolve(
                    url: _tap.link,
                    wallpaperId: _tap.contentId,
                    wallpaperSource: _tap.wallpaperSource,
                    action: OriginalAccessAction.download,
                    requestId: _tap.requestId,
                    maxCoins: setDesktop == null ? serverRequiredCoins : phoneCoins,
                    desktop: _tap.desktop != null,
                    desktopVersion: _tap.desktop?.version,
                  );
                  if (setDesktop != null) _authorizedDesktop = await _resolveSetDesktop(setDesktop, setDesktopCoins);
                  return CoinMutationResult(
                    success: true,
                    // Original-access receipts do not use CoinGate's spend/refund ledger.
                    changed: false,
                    previousBalance: balance,
                    currentBalance: CoinsService.instance.balanceNotifier.value,
                    delta: CoinsService.instance.balanceNotifier.value - balance,
                  );
                } on OriginalAccessInsufficientBalance catch (error) {
                  phoneCoins = error.requiredCoins;
                  serverRequiredCoins = error.requiredCoins + (setDesktopCoins ?? 0);
                  serverBalance = error.currentBalance;
                  return CoinMutationResult(
                    success: false,
                    changed: false,
                    previousBalance: error.currentBalance,
                    currentBalance: error.currentBalance,
                    delta: 0,
                    insufficientBalance: true,
                  );
                }
              },
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
        precheckBalance: !originalAccess && !_downloadIsFree(_tap.isPremiumContent),
        repromptOnNudgeSpendInsufficient: false,
        onPaid: (String txId) => _paidTxId = txId,
        isMounted: () => mounted && _ownerStillMatches(_tap),
        perform: !originalAccess
            ? _performDownload
            : () async {
                if (!_ownerStillMatches(_tap)) return false;
                if (variant != null) {
                  _preparedSource = await runPrepareSource(
                    variant.prepareAuthorized == null
                        ? variant.prepare
                        : () => variant.prepareAuthorized!(_authorizedSource!),
                    l10n: context.l10n,
                  );
                  if (_preparedSource == null || !_ownerStillMatches(_tap)) return false;
                }
                return _performDownload();
              },
        choose: (prompt) async {
          final actualPrompt = CoinGatePrompt(
            phase: prompt.phase,
            cost: serverRequiredCoins ?? prompt.cost,
            balance: setDesktop == null ? serverBalance ?? prompt.balance : CoinsService.instance.balanceNotifier.value,
            adsAllowed: prompt.adsAllowed,
            adsRemaining: prompt.adsRemaining,
          );
          if (originalAccess && actualPrompt.canSpend) {
            return await showCoinGateSheet<CoinGateChoice>(
                  context,
                  title: context.l10n.economyDownload,
                  cost: actualPrompt.cost,
                  message: (_) => context.l10n.economyDownloadCost(context.l10n.economyDownload, actualPrompt.cost),
                  options: [CoinGateOption(label: context.l10n.economyDownload, value: CoinGateChoice.spend)],
                ) ??
                CoinGateChoice.cancel;
          }
          return _chooseLowBalanceAction(actualPrompt);
        },
        onWatchChosen: () => CoinsService.instance.logWatchAndDownloadUsed(
          isPremiumContent: _tap.isPremiumContent,
          sourceTag: 'coins.download.watch_and_download',
        ),
      ),
    );
  }

  /// The desktop version of a set, granted after the phone wall in the same gate run. A refusal leaves the set without
  /// it: the phone wall is already paid, so the set still saves.
  Future<String?> _resolveSetDesktop(WallDesktopVariant desktop, int? maxCoins) async {
    if (!_ownerStillMatches(_tap)) return null;
    try {
      return await OriginalAccessService.instance.resolve(
        url: '',
        wallpaperId: _tap.contentId,
        wallpaperSource: _tap.wallpaperSource,
        action: OriginalAccessAction.download,
        maxCoins: maxCoins,
        desktop: true,
        desktopVersion: desktop.version,
      );
    } catch (error, stackTrace) {
      logger.w('The desktop version of a set was not granted', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> _performDownload({File? cachedOriginalForRestore}) async {
    final AppLocalizations l10n = context.l10n;
    final _DownloadTap tap = _tap;
    if (!_ownerStillMatches(tap)) return false;
    final String link = tap.link;
    final String? sourceContext = tap.sourceContext;
    final bool premiumContent = tap.isPremiumContent;
    final VoidCallback? onDownloaded = tap.onDownloaded;
    if (link.isEmpty && _authorizedSource == null) {
      toasts.error(context.l10n.economyDownloadLinkUnavailable);
      return false;
    }
    final bool prepared = _preparedSource != null;
    final OfflineAssetStore assetStore = OfflineAssetStore.instance;
    File? cachedOriginal = cachedOriginalForRestore;
    if (!prepared && cachedOriginal == null && _authorizedSource == null) {
      try {
        cachedOriginal = await assetStore.lookup(link);
      } catch (error, stackTrace) {
        logger.w('Could not inspect the wallpaper cache before saving', error: error, stackTrace: stackTrace);
      }
    }
    final String saveLink = _preparedSource ?? cachedOriginal?.path ?? _authorizedSource ?? link;
    final Uri? sourceUri = Uri.tryParse(saveLink);
    final bool isLocalFile =
        prepared || cachedOriginal != null || saveLink.startsWith('/') || sourceUri?.scheme == 'file';
    final List<String> downloadsBefore = await _listedDownloads();
    if (!_ownerStillMatches(tap)) {
      _cancelAfterAccountSwitch();
      return false;
    }
    final DownloadSet? set = tap.set;
    if (set != null) {
      try {
        await _discardSetFiles();
        _setFiles = await set.prepare(saveLink);
      } catch (error, stackTrace) {
        logger.w('Could not prepare the files of a set', error: error, stackTrace: stackTrace);
        _failureReason = 'set_prepare_failed';
        _failureStage = 'prepare';
        toasts.error(l10n.economyAiDownloadFailed);
        return false;
      }
      if (!_ownerStillMatches(tap)) {
        _cancelAfterAccountSwitch();
        return false;
      }
    }
    bool setDesktopSaved = false;
    final Set<String> savedSetKeys = <String>{};
    bool setInterrupted = false;

    try {
      final DownloadRequest request = DownloadRequest(
        link: saveLink,
        filenameWithoutExtension: downloadBaseName(tap.fileIdentity),
        isLocalFile: isLocalFile,
      );
      final OperationResult result = await PrismMediaHostApi().enqueueDownload(request);
      if (!result.success) {
        _failureReason = isPhotosPermissionDenied(result.errorCode)
            ? 'permission_denied'
            : set == null
            ? 'enqueue_failed'
            : switch (result.errorCode) {
                'PHOTO_PERMISSION_RESTRICTED' => 'permission_restricted',
                'PHOTO_PERMISSION_UNKNOWN' => 'permission_unknown',
                'STORAGE_PERMISSION_REQUIRED' => 'storage_permission_required',
                _ => 'enqueue_failed',
              };
        if (isPhotosPermissionDenied(result.errorCode)) {
          if (mounted) showPhotosPermissionDenied(context);
        } else {
          toasts.error(
            result.errorCode == 'STORAGE_PERMISSION_REQUIRED'
                ? l10n.wallpaperDownloadsLoadHelp
                : l10n.economyAiDownloadFailed,
          );
          unawaited(RatePromptService.instance.recordFailure());
        }
        return false;
      }
      for (final MapEntry<String, String> file in _setFiles.entries) {
        if (!_ownerStillMatches(tap)) {
          setInterrupted = true;
          break;
        }
        final OperationResult saved = await PrismMediaHostApi().enqueueDownload(
          DownloadRequest(
            link: file.value,
            filenameWithoutExtension: downloadBaseName(DownloadVariant.identityFor(tap.fileIdentity, file.key)),
            isLocalFile: true,
          ),
        );
        if (!saved.success) {
          toasts.error(l10n.economyAiDownloadFailed);
          break;
        }
        savedSetKeys.add(file.key);
      }
      final WallDesktopVariant? setDesktop = set?.desktop;
      final String? desktopSource = _authorizedDesktop;
      if (setDesktop != null && desktopSource != null && _ownerStillMatches(tap)) {
        setDesktopSaved = await _saveSetDesktop(tap, setDesktop, desktopSource);
      }
      if (set != null && !_ownerStillMatches(tap)) {
        setInterrupted = true;
        _cancelAfterAccountSwitch();
      }
      if (tap.contentId != null && tap.wallpaperSource == WallpaperSource.prism) {
        await OriginalAccessService.instance.complete(
          owner: tap.ownerId,
          wallpaperId: OriginalAccessService.grantKey(
            tap.contentId!,
            desktop: tap.desktop != null,
            desktopVersion: tap.desktop?.version,
          ),
          action: OriginalAccessAction.download,
        );
      }
      if (!prepared && tap.desktop == null) {
        await _retainCompletedOriginal(
          assetStore,
          _originalIdentity(link, tap.contentId),
          cachedOriginal,
          downloadsBefore,
          result.message,
        );
      }
    } on PlatformException catch (e) {
      _failureReason = 'platform_error';
      if (e.code == 'channel-error') {
        logger.w('Download channel unavailable (native side not registered)', error: e);
      } else {
        logger.e('Download failed', error: e);
      }
      toasts.error(l10n.economyAiDownloadFailed);
      unawaited(RatePromptService.instance.recordFailure());
      return false;
    } catch (e, stackTrace) {
      _failureReason = 'unexpected';
      logger.e('Unexpected download failure', error: e, stackTrace: stackTrace);
      toasts.error(l10n.errorGeneric);
      unawaited(RatePromptService.instance.recordFailure());
      return false;
    }

    final String? paidTxId = _paidTxId;
    if (paidTxId != null) await CoinsService.instance.markPendingDownloadSaved(paidTxId);

    final String? contentId = tap.contentId?.trim();
    final WallpaperSource? wallpaperSource = tap.indexSource;
    final bool isBundledStarter =
        contentId != null &&
        contentId.isNotEmpty &&
        wallpaperSource != null &&
        BundledWallpapers.isStarterIdentity(contentId, wallpaperSource);
    if (!isBundledStarter &&
        contentId != null &&
        contentId.isNotEmpty &&
        wallpaperSource != null &&
        getIt.isRegistered<DownloadedWallIndex>()) {
      final DownloadedWallIndex index = getIt<DownloadedWallIndex>();
      await index.remember(
        link: tap.fileIdentity,
        id: contentId,
        source: wallpaperSource,
        ownerId: tap.ownerId,
        original: !prepared && tap.desktop == null && tap.indexSource == tap.wallpaperSource,
      );
      for (final String key in <String>[...savedSetKeys, if (setDesktopSaved) 'desktop-${set!.desktop!.version}']) {
        await index.remember(
          link: DownloadVariant.identityFor(tap.fileIdentity, key),
          id: contentId,
          source: wallpaperSource,
          ownerId: tap.ownerId,
          original: false,
        );
      }
    }

    try {
      analytics.track(
        DownloadWallpaperEvent(
          link: link,
          sourceContext: (sourceContext ?? '').trim().isEmpty ? null : sourceContext,
          premiumContent: premiumContent,
          operationId: tap.operationId,
          requestId: tap.requestId,
          itemId: tap.contentId,
          provider: tap.wallpaperSource?.name,
          source: tap.sourceContext,
        ),
      );
    } catch (e, stackTrace) {
      logger.w('Download analytics failed after media was saved', error: e, stackTrace: stackTrace);
    }

    final bool setComplete = savedSetKeys.length == _setFiles.length;
    if (mounted && _ownerStillMatches(tap) && tap.identity == _currentIdentity && !setInterrupted && setComplete) {
      setState(() => _saved = true);
    }
    final String recordedContentId = tap.contentId?.trim() ?? '';
    if (!isBundledStarter && recordedContentId.isNotEmpty) {
      unawaited(_recordAward(recordedContentId, tap));
    }
    try {
      // This async save may finish after the owning page is disposed. Keep the
      // localized copy captured before the first await for the global toast.
      if (set == null) {
        toasts.success(savedWallpaperMessage(l10n: l10n, depthTier: tap.depthTier, spatialTier: tap.spatialTier));
      }
      if (!setInterrupted) {
        onDownloaded?.call();
        set?.onSaved?.call(
          desktopSaved: setDesktopSaved,
          files: <String, String>{for (final String key in savedSetKeys) key: _setFiles[key]!},
        );
      }
    } catch (e, stackTrace) {
      logger.w('Download follow-up failed after media was saved', error: e, stackTrace: stackTrace);
    }
    if (mounted && set == null) {
      try {
        await showIosSetWallpaperGuide(
          context,
          depthTier: tap.depthTier,
          spatialTier: tap.spatialTier,
          duoReveal: tap.duoReveal,
        );
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
        unawaited(RatePromptService.instance.maybePrompt(RatePromptTrigger.download));
      } catch (e, stackTrace) {
        logger.w('Rate prompt after download failed', error: e, stackTrace: stackTrace);
      }
    }
    return true;
  }

  /// Saves the granted desktop version of a set. On failure its grant stays open, so a retry in the grant's window does
  /// not charge again.
  Future<bool> _saveSetDesktop(_DownloadTap tap, WallDesktopVariant desktop, String source) async {
    try {
      final OperationResult result = await PrismMediaHostApi().enqueueDownload(
        DownloadRequest(
          link: source,
          filenameWithoutExtension: downloadBaseName(
            DownloadVariant.identityFor(tap.fileIdentity, 'desktop-${desktop.version}'),
          ),
          isLocalFile: false,
        ),
      );
      if (!result.success) return false;
      await OriginalAccessService.instance.complete(
        owner: tap.ownerId,
        wallpaperId: OriginalAccessService.grantKey(tap.contentId!, desktop: true, desktopVersion: desktop.version),
        action: OriginalAccessAction.download,
      );
      return true;
    } catch (error, stackTrace) {
      logger.w('The desktop version of a set was not saved', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _discardSetFiles() async {
    final Iterable<String> paths = _setFiles.values;
    _setFiles = const <String, String>{};
    for (final String path in paths) {
      try {
        await File(path).delete();
      } on FileSystemException {
        continue;
      }
    }
  }

  Future<List<String>> _listedDownloads() async {
    try {
      final DownloadItemsResult result = await PrismMediaHostApi().listDownloads();
      return result.success ? result.items : const <String>[];
    } catch (error, stackTrace) {
      logger.w('Could not list downloads before transfer', error: error, stackTrace: stackTrace);
      return const <String>[];
    }
  }

  Future<void> _retainCompletedOriginal(
    OfflineAssetStore store,
    String source,
    File? cachedOriginal,
    List<String> downloadsBefore,
    String? nativePath,
  ) async {
    try {
      File? completedFile = cachedOriginal;
      if (completedFile == null &&
          nativePath != null &&
          nativePath.startsWith('/') &&
          await File(nativePath).exists()) {
        completedFile = File(nativePath);
      }
      if (completedFile == null) {
        final List<String> after = await _listedDownloads();
        final Set<String> before = downloadsBefore.toSet();
        final String expectedName = downloadBaseName(_tap.fileIdentity);
        final List<File> newMatches = after
            .where((path) => !before.contains(path) && File(path).existsSync())
            .where((path) {
              final String name = p.basenameWithoutExtension(path).replaceFirst(RegExp(r' \(\d+\)$'), '');
              return name == expectedName;
            })
            .map(File.new)
            .toList(growable: false);
        if (newMatches.length == 1) completedFile = newMatches.single;
      }
      if (completedFile != null) await store.retain(source, file: completedFile);
    } catch (error, stackTrace) {
      logger.w(
        'Wallpaper was saved to Downloads, but its in-app offline original could not be retained',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
