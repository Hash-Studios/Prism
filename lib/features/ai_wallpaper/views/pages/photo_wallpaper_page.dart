import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/photo_wallpaper_repository.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_decoded_image.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/photo_wallpaper_widgets.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/views/widgets/folder_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

Future<void> openPhotoWallpaperPage(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => PhotoWallpaperPage(repository: PhotoWallpaperRepository())));

/// Make a wallpaper from a photo: pick, plan, place, run, then compare and use the result.
class PhotoWallpaperPage extends StatefulWidget {
  const PhotoWallpaperPage({super.key, required this.repository, this.initialSource, this.isPro, this.screenSize});

  final PhotoWallpaperRepository repository;

  /// A photo the user already chose, such as one shared from another app. The page opens on its plan.
  final PhotoSource? initialSource;

  /// Test seams. Null reads the signed-in user and the screen.
  final bool? isPro;
  final PhotoSize? screenSize;

  @override
  State<PhotoWallpaperPage> createState() => _PhotoWallpaperPageState();
}

class _PhotoWallpaperPageState extends State<PhotoWallpaperPage> {
  PhotoSource? _source;
  PhotoJobTarget _target = PhotoJobTarget.phone;
  PhotoPlacement? _placement;
  PhotoJobState _state = const PhotoJobDraft();

  /// Kept across a retry after a dropped connection or a job still in progress, so the server replays it.
  String? _pendingRequestId;
  bool _picking = false;
  bool _acting = false;
  bool _initialApplied = false;

  /// The mode of a job recovered after a restart. The photo itself is not kept, so [_mode] cannot plan it.
  PhotoJobMode? _recoveredMode;

  bool get _isPro => widget.isPro ?? app_state.prismUser.premium;

  String get _userId => app_state.prismUser.id;

  PhotoJobMode? get _jobMode => _mode ?? _recoveredMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPending());
  }

  /// True when the server outcome is final, so the saved request id can go.
  static bool _isFinal(PhotoJobState result) =>
      result is PhotoJobSucceeded ||
      (result is PhotoJobFailed &&
          result.reason != PhotoJobFailure.network &&
          result.reason != PhotoJobFailure.inProgress &&
          !(result.charged && !result.refunded));

  /// Shows the result of a job that was running when the app closed, or its refund.
  Future<void> _recoverPending() async {
    final PendingPhotoJob? pending = await widget.repository.readPending();
    if (!mounted || pending == null || pending.userId != _userId || _source != null || _running) return;
    setState(() {
      _target = pending.target;
      _recoveredMode = pending.mode;
      _pendingRequestId = pending.requestId;
      _state = PhotoJobRunning(pending.requestId);
    });
    final PhotoJobState? result = await widget.repository.recover(pending.requestId);
    if (!mounted) return;
    final PhotoJobState shown = switch (result) {
      null => const PhotoJobDraft(),
      PhotoJobRunning() => const PhotoJobFailed(reason: PhotoJobFailure.inProgress, charged: false, refunded: false),
      _ => result,
    };
    if (result == null || _isFinal(shown)) unawaited(widget.repository.savePending(null));
    unawaited(CoinsService.instance.refreshBalance().then<void>((_) {}, onError: (Object _) {}));
    setState(() {
      _state = shown;
      if (result == null) _recoveredMode = null;
      if (result == null || _isFinal(shown)) _pendingRequestId = null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialApplied && widget.initialSource != null) {
      _initialApplied = true;
      _source = widget.initialSource;
      _replan();
    }
  }

  PhotoSize get _phone {
    if (widget.screenSize case final PhotoSize size?) return size;
    final Size logical = MediaQuery.sizeOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return phoneTargetSize(width: logical.width * dpr, height: logical.height * dpr);
  }

  PhotoSize get _canvas => targetSizeFor(_target, _phone);

  PhotoJobMode? get _mode => _source == null ? null : planPhotoJob(_source!.size, _canvas);

  int get _cost => _mode == null ? 0 : photoJobCost(_mode!, isPro: _isPro);

  bool get _running => _state is PhotoJobRunning;

  void _replan() {
    final PhotoSource? source = _source;
    _placement = source != null && _mode == PhotoJobMode.extend
        ? PhotoPlacement.fit(canvas: _canvas, photo: source.size)
        : null;
  }

  Future<void> _pick() async {
    if (_picking || _running) return;
    setState(() => _picking = true);
    try {
      final PhotoSource? source = await widget.repository.pick();
      if (!mounted || source == null) return;
      setState(() {
        _source = source;
        _state = const PhotoJobDraft();
        _pendingRequestId = null;
        _replan();
      });
    } catch (error) {
      logger.w('[PhotoWallpaper] pick failed (${error.runtimeType})');
      if (mounted) toasts.error(context.l10n.photoWallErrorUnreadable);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _setTarget(PhotoJobTarget target) {
    if (_running || target == _target) return;
    setState(() {
      _target = target;
      _state = const PhotoJobDraft();
      _pendingRequestId = null;
      _replan();
    });
  }

  Future<void> _run() async {
    final PhotoSource? source = _source;
    final PhotoJobMode? mode = _mode;
    if (source == null || mode == null || _running) return;
    final String owner = app_state.prismUser.id;
    bool mayUpload() => mounted && app_state.prismUser.loggedIn && owner.isNotEmpty && app_state.prismUser.id == owner;
    void signedOut() {
      if (!mounted) return;
      setState(() {
        _state = const PhotoJobFailed(reason: PhotoJobFailure.signIn, charged: false, refunded: false);
        _pendingRequestId = null;
      });
    }

    if (!mayUpload()) {
      signedOut();
      return;
    }
    if (mode == PhotoJobMode.extend && !(_placement?.validForServer ?? false)) {
      setState(() {
        _state = const PhotoJobFailed(reason: PhotoJobFailure.unreadable, charged: false, refunded: false);
        _pendingRequestId = null;
      });
      return;
    }
    final PhotoJob job = PhotoJob(source: source, mode: mode, target: _target, cost: _cost);
    final String requestId = _pendingRequestId ?? AnalyticsCorrelation.newId();
    final AppLocalizations l10n = context.l10n;
    final PhotoSize canvas = _canvas;
    setState(() {
      _pendingRequestId = requestId;
      _recoveredMode = null;
      _state = PhotoJobRunning(requestId);
    });
    await widget.repository.savePending(
      PendingPhotoJob(userId: _userId, requestId: requestId, mode: mode, target: _target),
    );
    analytics.track(PhotoJobStartedEvent(mode: mode.analytics, target: _target.analytics, cost: job.cost));
    final AiGenerationActivity? activity = await LiveActivityChannel.startAiGeneration(
      AiActivityRequest(
        prompt: mode == PhotoJobMode.extend ? l10n.photoWallWorkingExtend : l10n.photoWallWorkingUpscale,
        style: _target == PhotoJobTarget.desktop ? l10n.photoWallTargetDesktop : l10n.photoWallTargetPhone,
        accentArgb: mounted ? Theme.of(context).colorScheme.primary.toARGB32() : 0xFF000000,
        swatchArgb: const <int>[],
        generatingTitle: l10n.aiLiveActivityGenerating,
        readyTitle: l10n.aiLiveActivityReady,
        failedTitle: l10n.aiLiveActivityFailed,
        staleTitle: l10n.aiLiveActivityStale,
        openLabel: l10n.aiLiveActivityOpen,
      ),
    );
    if (!mayUpload()) {
      await activity?.cancel();
      signedOut();
      return;
    }
    final PhotoJobState result = await widget.repository.run(
      job,
      requestId: requestId,
      targetSize: canvas,
      placement: _placement,
      mayUpload: mayUpload,
    );
    if (!mayUpload()) {
      await activity?.cancel();
      signedOut();
      return;
    }
    unawaited(CoinsService.instance.refreshBalance().then<void>((_) {}, onError: (Object _) {}));
    switch (result) {
      case PhotoJobSucceeded(:final String imageUrl):
        PrismHaptics.success();
        await activity?.finish(imageUrl);
        analytics.track(PhotoJobDoneEvent(mode: mode.analytics, target: _target.analytics, cost: job.cost));
      case PhotoJobFailed(:final PhotoJobFailure reason, :final bool refunded):
        await activity?.fail(_errorText(l10n, result));
        analytics.track(
          PhotoJobFailedEvent(mode: mode.analytics, target: _target.analytics, reason: reason.wire, refunded: refunded),
        );
      case PhotoJobDraft() || PhotoJobRunning():
        await activity?.cancel();
    }
    if (_isFinal(result)) unawaited(widget.repository.savePending(null));
    if (!mounted) return;
    setState(() {
      _state = result;
      if (_isFinal(result)) _pendingRequestId = null;
    });
  }

  String _errorText(AppLocalizations l10n, PhotoJobFailed failed) {
    final String message = switch (failed.reason) {
      PhotoJobFailure.unsafeInput => l10n.photoWallErrorUnsafeInput,
      PhotoJobFailure.unsafeOutput => l10n.photoWallErrorUnsafeOutput,
      PhotoJobFailure.dailyLimit => l10n.photoWallErrorLimit(10),
      PhotoJobFailure.busy => l10n.photoWallErrorBusy,
      PhotoJobFailure.unreadable => l10n.photoWallErrorUnreadable,
      PhotoJobFailure.inProgress => l10n.photoWallErrorInProgress,
      PhotoJobFailure.insufficientCoins => l10n.photoWallGetCoins(_cost),
      _ => l10n.photoWallErrorGeneric,
    };
    if (!failed.charged) return message;
    return '$message ${failed.refunded ? l10n.photoWallRefunded(failed.cost ?? _cost) : l10n.photoWallRefundPending}';
  }

  Future<File?> _resultFile(PhotoJobSucceeded done) async {
    try {
      return await aiDownloadToTempFile(done.imageUrl);
    } catch (error) {
      logger.w('[PhotoWallpaper] result download failed (${error.runtimeType})');
      if (mounted) toasts.error(aiDownloadFailureMessage(context.l10n, error));
      return null;
    }
  }

  Future<void> _set(PhotoJobSucceeded done, PhotoJobMode mode) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      analytics.track(
        PhotoJobResultSetEvent(
          mode: mode.analytics,
          target: _target.analytics,
          platform: hideSetWallpaperUi ? 'ios' : 'android',
        ),
      );
      if (hideSetWallpaperUi) {
        await _download(done, guide: true);
        return;
      }
      final File? file = await _resultFile(done);
      if (file == null || !mounted) return;
      await SetWallpaperFlow.run(
        context,
        url: file.path,
        wallpaperSource: WallpaperSource.downloaded,
        forceScreen: true,
        entryPoint: 'photo_wallpaper',
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _download(PhotoJobSucceeded done, {bool guide = false}) async {
    final AppLocalizations l10n = context.l10n;
    try {
      final File local = await OfflineAssetStore.instance.resolve(done.imageUrl).timeout(aiAssetTransferTimeout);
      final OperationResult result = await PrismMediaHostApi().enqueueDownload(
        DownloadRequest(link: local.path, filenameWithoutExtension: downloadBaseName(done.imageUrl), isLocalFile: true),
      );
      if (!mounted) return;
      if (result.success) {
        toasts.success(l10n.photoWallSaved);
        if (guide) await showIosSetWallpaperGuide(context);
      } else if (isPhotosPermissionDenied(result.errorCode)) {
        showPhotosPermissionDenied(context);
      } else {
        toasts.error(l10n.economyAiDownloadFailed);
      }
    } catch (error) {
      logger.w('[PhotoWallpaper] save failed (${error.runtimeType})');
      if (mounted) toasts.error(aiDownloadFailureMessage(l10n, error));
    }
  }

  Future<void> _saveToFolder(PhotoJobSucceeded done, PhotoJobMode mode) {
    final String id = done.jobId;
    final WallpaperCore core = WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: done.imageUrl,
      thumbnailUrl: done.imageUrl,
      width: done.size.width,
      height: done.size.height,
      resolution: '${done.size.width}x${done.size.height}',
      authorUid: app_state.prismUser.id,
      authorName: app_state.prismUser.username,
      createdAt: DateTime.now(),
    );
    final PrismWallpaper wall = PrismWallpaper(
      core: core,
      isAiGenerated: true,
      aiModel: mode.model,
      firestoreDocumentId: id,
    );
    return showFolderSheet(context, PrismFavouriteWall(id: id, wallpaper: wall));
  }

  void _startOver() {
    setState(() {
      _source = null;
      _state = const PhotoJobDraft();
      _pendingRequestId = null;
      _placement = null;
      _recoveredMode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PopScope(
      canPop: !_running,
      child: PrismPage(
        title: l10n.photoWallEntryTitle,
        actions: const <Widget>[CoinBalanceChip(sourceTag: 'photo_wallpaper_page', showStreak: false)],
        bottomBar: _bottomBar(l10n),
        body: AnimatedSwitcher(
          duration: context.motion(PrismDurations.base),
          reverseDuration: context.motion(PrismDurations.fast),
          switchInCurve: PrismCurves.enter,
          switchOutCurve: PrismCurves.exitReverse,
          child: KeyedSubtree(key: ValueKey<Object>(_bodyKey), child: _body(l10n)),
        ),
      ),
    );
  }

  Object get _bodyKey => switch (_state) {
    PhotoJobDraft() => _source == null ? 'empty' : 'draft',
    PhotoJobRunning() => 'running',
    PhotoJobSucceeded() => 'done',
    PhotoJobFailed() => 'failed',
  };

  Widget _body(AppLocalizations l10n) {
    final PhotoSource? source = _source;
    if (source == null && _state is PhotoJobDraft) return _empty(l10n);
    return SingleChildScrollView(
      padding: PrismSpace.pageInsets.copyWith(top: PrismSpace.xs, bottom: PrismSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (_state) {
          PhotoJobSucceeded() && final PhotoJobSucceeded done => _done(l10n, source, done),
          PhotoJobFailed() && final PhotoJobFailed failed => _failed(l10n, failed),
          PhotoJobRunning() => _working(l10n, source),
          PhotoJobDraft() => _draft(l10n, source!),
        },
      ),
    );
  }

  Widget _empty(AppLocalizations l10n) => ListView(
    padding: PrismSpace.pageInsets.copyWith(top: PrismSpace.xxl),
    children: <Widget>[
      GlintState(
        kind: GlintStateKind.empty,
        title: l10n.photoWallEntrySubtitle,
        body: l10n.photoWallPrivacyNote,
        actionLabel: l10n.photoWallPickPhoto,
        onAction: _picking ? null : _pick,
      ),
    ],
  );

  Widget _preview(PhotoSource source) {
    final PhotoPlacement? placement = _placement;
    if (placement != null) return PhotoInCanvas(source: source, placement: placement);
    return Image.memory(source.bytes, fit: BoxFit.cover, gaplessPlayback: true);
  }

  List<Widget> _draft(AppLocalizations l10n, PhotoSource source) {
    final PhotoPlacement? placement = _placement;
    return <Widget>[
      Text(l10n.photoWallTargetLabel, style: PrismTextStyles.rowTitle(context)),
      const SizedBox(height: PrismSpace.xs),
      PrismSegmented<PhotoJobTarget>(
        values: PhotoJobTarget.values,
        selected: _target,
        labelOf: (PhotoJobTarget t) =>
            t == PhotoJobTarget.phone ? l10n.photoWallTargetPhone : l10n.photoWallTargetDesktop,
        iconOf: (PhotoJobTarget t) =>
            t == PhotoJobTarget.phone ? Icons.smartphone_rounded : Icons.desktop_windows_rounded,
        onChanged: _setTarget,
      ),
      const SizedBox(height: PrismSpace.md),
      PhotoPlanCard(mode: _mode, target: _target),
      const SizedBox(height: PrismSpace.xl),
      if (placement != null) ...<Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(l10n.photoWallPlaceTitle, style: PrismTextStyles.sectionTitle(context))),
            if (!placement.isFit)
              PrismButton(
                label: l10n.photoWallPlaceReset,
                variant: PrismButtonVariant.ghost,
                size: PrismButtonSize.compact,
                onPressed: () => setState(() => _placement = PhotoPlacement.fit(canvas: _canvas, photo: source.size)),
              ),
          ],
        ),
        const SizedBox(height: PrismSpace.xs),
        PhotoPlacementFrame(
          source: source,
          placement: placement,
          onChanged: (PhotoPlacement next) => setState(() => _placement = next),
        ),
        const SizedBox(height: PrismSpace.xs),
        Text(l10n.photoWallPlaceHint, style: PrismTextStyles.caption(context), textAlign: TextAlign.center),
      ] else
        PhotoFrame(canvas: _canvas, child: _preview(source)),
      const SizedBox(height: PrismSpace.lg),
      Text(l10n.photoWallPrivacyNote, style: PrismTextStyles.caption(context)),
    ];
  }

  List<Widget> _working(AppLocalizations l10n, PhotoSource? source) => <Widget>[
    PhotoFrame(
      canvas: _canvas,
      child: _Breathing(
        child: source == null
            ? ColoredBox(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06))
            : _preview(source),
      ),
    ),
    const SizedBox(height: PrismSpace.lg),
    Semantics(
      liveRegion: true,
      child: Text(
        _jobMode == PhotoJobMode.upscale ? l10n.photoWallWorkingUpscale : l10n.photoWallWorkingExtend,
        style: PrismTextStyles.sectionTitle(context),
        textAlign: TextAlign.center,
      ),
    ),
    const SizedBox(height: PrismSpace.xxs),
    Text(l10n.photoWallWorkingDetail, style: PrismTextStyles.body(context), textAlign: TextAlign.center),
    const SizedBox(height: PrismSpace.md),
    const LinearProgressIndicator(),
  ];

  List<Widget> _done(AppLocalizations l10n, PhotoSource? source, PhotoJobSucceeded done) {
    final Widget after = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) =>
          AiDecodedImage(url: done.imageUrl, logicalWidth: box.maxWidth, logicalHeight: box.maxHeight),
    );
    // A job recovered after a restart has no photo to compare with, so it shows the result alone.
    if (source == null) return <Widget>[PhotoFrame(canvas: done.size, child: after)];
    return <Widget>[PhotoCompareView(canvas: done.size, before: _preview(source), after: after)];
  }

  List<Widget> _failed(AppLocalizations l10n, PhotoJobFailed failed) => <Widget>[
    GlintState(
      kind: GlintStateKind.error,
      title: _errorText(l10n, failed),
      actionLabel: switch (failed.reason) {
        PhotoJobFailure.unsafeInput || PhotoJobFailure.unreadable => l10n.photoWallPickAnother,
        PhotoJobFailure.dailyLimit || PhotoJobFailure.busy => null,
        _ when _source == null && _isFinal(failed) => l10n.photoWallPickPhoto,
        _ => l10n.photoWallTryAgain,
      },
      onAction: switch (failed.reason) {
        PhotoJobFailure.unsafeInput || PhotoJobFailure.unreadable => _pick,
        PhotoJobFailure.dailyLimit || PhotoJobFailure.busy => null,
        _ when _source == null => _isFinal(failed) ? _pick : _recoverPending,
        _ => _run,
      },
    ),
  ];

  Widget? _bottomBar(AppLocalizations l10n) {
    final PhotoJobState state = _state;
    final PhotoSource? source = _source;
    if (state is PhotoJobRunning) return null;
    if (state case final PhotoJobSucceeded done) {
      final PhotoJobMode mode = _jobMode ?? PhotoJobMode.extend;
      return _BarColumn(
        children: <Widget>[
          PrismButton(
            label: l10n.photoWallSet,
            icon: Icons.wallpaper_rounded,
            expand: true,
            loading: _acting,
            onPressed: () => _set(done, mode),
          ),
          Row(
            children: <Widget>[
              if (!hideSetWallpaperUi) ...<Widget>[
                Expanded(
                  child: PrismButton(
                    label: l10n.photoWallDownload,
                    variant: PrismButtonVariant.tonal,
                    expand: true,
                    maxLines: null,
                    onPressed: () => _download(done),
                  ),
                ),
                const SizedBox(width: PrismSpace.xs),
              ],
              Expanded(
                child: PrismButton(
                  label: l10n.foldersSaveToFolder,
                  variant: PrismButtonVariant.tonal,
                  expand: true,
                  maxLines: null,
                  onPressed: () => _saveToFolder(done, mode),
                ),
              ),
            ],
          ),
          PrismButton(
            label: l10n.photoWallStartOver,
            variant: PrismButtonVariant.ghost,
            expand: true,
            onPressed: _startOver,
          ),
        ],
      );
    }
    if (source == null) return null;
    final PhotoJobMode? mode = _mode;
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (BuildContext context, int balance, _) {
        final int cost = _cost;
        final bool short = mode != null && balance < cost && _pendingRequestId == null;
        return _BarColumn(
          children: <Widget>[
            if (mode != null)
              PrismButton(
                key: const ValueKey<String>('photo-run'),
                label: short
                    ? l10n.photoWallGetCoins(cost - balance)
                    : mode == PhotoJobMode.extend
                    ? l10n.photoWallRunExtend(cost)
                    : l10n.photoWallRunUpscale(cost),
                icon: short ? Icons.toll_rounded : Icons.auto_awesome_rounded,
                expand: true,
                maxLines: 2,
                onPressed: short ? () => context.router.push(RewardsRoute(scrollToEarn: true)) : _run,
              ),
            PrismButton(
              label: l10n.photoWallPickAnother,
              variant: mode == null ? PrismButtonVariant.primary : PrismButtonVariant.ghost,
              expand: true,
              loading: _picking,
              onPressed: _pick,
            ),
          ],
        );
      },
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: PrismSpace.xs),
            children[i],
          ],
        ],
      ),
    ),
  );
}

/// A slow opacity pulse while the job runs. Reduce motion keeps it still.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.child});

  final Widget child;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(
      begin: 0.55,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
    child: widget.child,
  );
}
