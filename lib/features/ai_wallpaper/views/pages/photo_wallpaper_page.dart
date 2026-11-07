import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
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
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
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
  const PhotoWallpaperPage({super.key, required this.repository, this.isPro, this.screenSize});

  final PhotoWallpaperRepository repository;

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
  bool _checkingPending = true;
  bool _pendingStorageReady = false;
  int _sessionRevision = 0;
  int? _activeRecoveryRevision;
  late String _owner;
  StreamSubscription<Object?>? _session;

  /// The mode of a job recovered after a restart. The photo itself is not kept, so [_mode] cannot plan it.
  PhotoJobMode? _recoveredMode;

  bool get _isPro => widget.isPro ?? app_state.prismUser.premium;

  String get _userId => app_state.prismUser.loggedIn ? app_state.prismUser.id : '';

  bool _isCurrent(int revision) => mounted && revision == _sessionRevision && _owner == _userId;

  bool _canUse(PhotoJobSucceeded done) => _owner == _userId && identical(_state, done);

  PhotoJobMode? get _jobMode => _recoveredMode ?? _mode;

  @override
  void initState() {
    super.initState();
    _owner = _userId;
    if (getIt.isRegistered<SessionRepository>()) {
      _session = getIt<SessionRepository>().watchCurrentUser().listen((user) {
        final String owner = user.loggedIn ? user.id : '';
        if (owner != _owner) _switchOwner(owner);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPending());
  }

  /// Resets the page for [owner] and looks up that account's own saved job.
  void _switchOwner(String owner) {
    _sessionRevision++;
    _activeRecoveryRevision = null;
    setState(() {
      _owner = owner;
      _source = null;
      _placement = null;
      _recoveredMode = null;
      _pendingRequestId = null;
      _state = const PhotoJobDraft();
      _picking = false;
      _acting = false;
      _checkingPending = true;
      _pendingStorageReady = false;
    });
    unawaited(_recoverPending());
  }

  @override
  void dispose() {
    unawaited(_session?.cancel());
    super.dispose();
  }

  /// True when the server outcome is final, so the saved request id can go.
  static bool _isFinal(PhotoJobState result) =>
      result is PhotoJobSucceeded ||
      (result is PhotoJobFailed &&
          (result.charged
              ? result.refunded
              : result.reason != PhotoJobFailure.network && result.reason != PhotoJobFailure.inProgress));

  Future<bool> _clearPending(String userId, String requestId) async {
    try {
      await widget.repository.clearPending(userId: userId, requestId: requestId);
      return true;
    } catch (error) {
      logger.w('[PhotoWallpaper] pending job clear failed (${error.runtimeType})');
      return false;
    }
  }

  /// Shows the result of a job that was running when the app closed, or its refund.
  Future<void> _recoverPending() async {
    final int revision = _sessionRevision;
    final String userId = _owner;
    if (!mounted || _activeRecoveryRevision == revision) return;
    _activeRecoveryRevision = revision;
    setState(() => _checkingPending = true);
    try {
      if (userId.isEmpty) return;
      final PendingPhotoJob? pending = await widget.repository.readPending(userId: userId);
      if (!_isCurrent(revision)) return;
      _pendingStorageReady = true;
      if (pending == null) {
        setState(() {
          _pendingRequestId = null;
          _recoveredMode = null;
          _state = const PhotoJobDraft();
        });
        return;
      }
      setState(() {
        if (_pendingRequestId != pending.requestId) {
          _source = null;
          _placement = null;
        }
        _target = pending.target;
        _recoveredMode = pending.mode;
        _pendingRequestId = pending.requestId;
        _state = PhotoJobRunning(pending.requestId);
      });
      final PhotoJobState? result = await widget.repository.recover(pending.requestId);
      if (!_isCurrent(revision)) return;
      final PhotoJobState shown = switch (result) {
        null => const PhotoJobDraft(),
        PhotoJobRunning() => const PhotoJobFailed(reason: PhotoJobFailure.inProgress, charged: false, refunded: false),
        _ => result,
      };
      final bool cleared = (result == null || _isFinal(shown)) && await _clearPending(userId, pending.requestId);
      if (!_isCurrent(revision)) return;
      setState(() {
        _state = shown;
        if (result == null) _recoveredMode = null;
        if (cleared) _pendingRequestId = null;
      });
    } catch (error) {
      logger.w('[PhotoWallpaper] pending job read failed (${error.runtimeType})');
      if (_isCurrent(revision)) {
        setState(() => _state = const PhotoJobFailed(reason: PhotoJobFailure.network, charged: false, refunded: false));
      }
    } finally {
      if (_isCurrent(revision)) {
        setState(() => _checkingPending = false);
        _activeRecoveryRevision = null;
      } else if (mounted && revision == _sessionRevision && _owner != _userId) {
        // The account changed without a session event (its persist failed), so nothing else resets the page.
        _switchOwner(_userId);
      }
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
    if (_picking || _running || _checkingPending || _owner.isEmpty) return;
    if (!_pendingStorageReady || _pendingRequestId != null) {
      await _recoverPending();
      return;
    }
    final int revision = _sessionRevision;
    setState(() => _picking = true);
    try {
      final PhotoSource? source = await widget.repository.pick();
      if (!_isCurrent(revision) || source == null) return;
      setState(() {
        _source = source;
        _recoveredMode = null;
        _state = const PhotoJobDraft();
        _pendingRequestId = null;
        _replan();
      });
    } catch (error) {
      logger.w('[PhotoWallpaper] pick failed (${error.runtimeType})');
      if (mounted && _isCurrent(revision)) toasts.error(context.l10n.photoWallErrorUnreadable);
    } finally {
      if (_isCurrent(revision)) setState(() => _picking = false);
    }
  }

  void _setTarget(PhotoJobTarget target) {
    if (_running || _checkingPending || _pendingRequestId != null || target == _target) return;
    setState(() {
      _target = target;
      _recoveredMode = null;
      _state = const PhotoJobDraft();
      _pendingRequestId = null;
      _replan();
    });
  }

  Future<void> _run() async {
    if (_running || _checkingPending || _picking) return;
    if (!_pendingStorageReady || _pendingRequestId != null) {
      await _recoverPending();
      return;
    }
    final PhotoSource? source = _source;
    final PhotoJobMode? mode = _mode;
    if (source == null || mode == null || _owner.isEmpty) return;
    if (mode == PhotoJobMode.extend && !(_placement?.validForServer ?? false)) {
      setState(() {
        _state = const PhotoJobFailed(reason: PhotoJobFailure.unreadable, charged: false, refunded: false);
        _pendingRequestId = null;
      });
      return;
    }
    final PhotoJob job = PhotoJob(source: source, mode: mode, target: _target, cost: _cost);
    final String requestId = AnalyticsCorrelation.newId();
    final String userId = _userId;
    final int revision = _sessionRevision;
    final AppLocalizations l10n = context.l10n;
    final PhotoSize canvas = _canvas;
    final PhotoPlacement? placement = _placement;
    setState(() {
      _pendingRequestId = requestId;
      _recoveredMode = mode;
      _state = PhotoJobRunning(requestId);
    });
    try {
      await widget.repository.savePending(
        PendingPhotoJob(userId: userId, requestId: requestId, mode: mode, target: job.target),
      );
    } catch (error) {
      logger.w('[PhotoWallpaper] pending job save failed (${error.runtimeType})');
      if (_isCurrent(revision)) {
        setState(() {
          _pendingRequestId = null;
          _pendingStorageReady = false;
          _state = const PhotoJobFailed(reason: PhotoJobFailure.network, charged: false, refunded: false);
        });
      }
      return;
    }
    if (!_isCurrent(revision)) return;
    analytics.track(PhotoJobStartedEvent(mode: mode.analytics, target: job.target.analytics, cost: job.cost));
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
    if (!_isCurrent(revision)) {
      await activity?.cancel();
      return;
    }
    final PhotoJobState result = await widget.repository.run(
      job,
      requestId: requestId,
      targetSize: canvas,
      placement: placement,
    );
    if (!_isCurrent(revision)) {
      await activity?.cancel();
      return;
    }
    switch (result) {
      case PhotoJobSucceeded(:final String imageUrl):
        PrismHaptics.success();
        await activity?.finish(imageUrl);
        if (!_isCurrent(revision)) return;
        analytics.track(PhotoJobDoneEvent(mode: mode.analytics, target: job.target.analytics, cost: job.cost));
      case PhotoJobFailed(:final PhotoJobFailure reason, :final bool refunded):
        await activity?.fail(_errorText(l10n, result));
        if (!_isCurrent(revision)) return;
        analytics.track(
          PhotoJobFailedEvent(
            mode: mode.analytics,
            target: job.target.analytics,
            reason: reason.wire,
            refunded: refunded,
          ),
        );
      case PhotoJobDraft() || PhotoJobRunning():
        await activity?.cancel();
    }
    if (!_isCurrent(revision)) return;
    final bool cleared = _isFinal(result) && await _clearPending(userId, requestId);
    if (!_isCurrent(revision)) return;
    setState(() {
      _state = result;
      if (cleared) _pendingRequestId = null;
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
    final int revision = _sessionRevision;
    try {
      return await aiDownloadToTempFile(done.imageUrl);
    } catch (error) {
      logger.w('[PhotoWallpaper] result download failed (${error.runtimeType})');
      if (_isCurrent(revision)) toasts.error(aiDownloadFailureMessage(context.l10n, error));
      return null;
    }
  }

  Future<void> _set(PhotoJobSucceeded done, PhotoJobMode mode) async {
    if (_acting || !_canUse(done)) return;
    final int revision = _sessionRevision;
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
      if (file == null || !mounted || !_isCurrent(revision) || !_canUse(done)) return;
      await SetWallpaperFlow.run(
        context,
        url: file.path,
        wallpaperSource: WallpaperSource.downloaded,
        forceScreen: true,
        entryPoint: 'photo_wallpaper',
      );
    } finally {
      if (_isCurrent(revision)) setState(() => _acting = false);
    }
  }

  Future<void> _download(PhotoJobSucceeded done, {bool guide = false}) async {
    if (!_canUse(done)) return;
    final int revision = _sessionRevision;
    final AppLocalizations l10n = context.l10n;
    try {
      final File local = await OfflineAssetStore.instance.resolve(done.imageUrl).timeout(aiAssetTransferTimeout);
      if (!_isCurrent(revision) || !_canUse(done)) return;
      final OperationResult result = await PrismMediaHostApi().enqueueDownload(
        DownloadRequest(link: local.path, filenameWithoutExtension: downloadBaseName(done.imageUrl), isLocalFile: true),
      );
      if (!mounted || !_isCurrent(revision) || !_canUse(done)) return;
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
      if (_isCurrent(revision)) toasts.error(aiDownloadFailureMessage(l10n, error));
    }
  }

  Future<void> _saveToFolder(PhotoJobSucceeded done, PhotoJobMode mode) {
    if (!_canUse(done)) return Future<void>.value();
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
    if (_pendingRequestId != null) {
      unawaited(_recoverPending());
      return;
    }
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
          key: ValueKey<int>(_sessionRevision),
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
        onAction: _picking || _checkingPending || _owner.isEmpty ? null : _pick,
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
    final int revision = _sessionRevision;
    bool canEdit() => _isCurrent(revision) && _state is PhotoJobDraft && identical(_source, source);
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
        onChanged: (PhotoJobTarget target) {
          if (canEdit()) _setTarget(target);
        },
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
                onPressed: () {
                  if (canEdit()) setState(() => _placement = PhotoPlacement.fit(canvas: _canvas, photo: source.size));
                },
              ),
          ],
        ),
        const SizedBox(height: PrismSpace.xs),
        PhotoPlacementFrame(
          source: source,
          placement: placement,
          onChanged: (PhotoPlacement next) {
            if (canEdit()) setState(() => _placement = next);
          },
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
        _ when _pendingRequestId != null && !_isFinal(failed) => l10n.photoWallTryAgain,
        PhotoJobFailure.unsafeInput || PhotoJobFailure.unreadable => l10n.photoWallPickAnother,
        PhotoJobFailure.dailyLimit || PhotoJobFailure.busy => null,
        _ when _source == null && _isFinal(failed) => l10n.photoWallPickPhoto,
        _ => l10n.photoWallTryAgain,
      },
      onAction: switch (failed.reason) {
        _ when _checkingPending => null,
        _ when _pendingRequestId != null && !_isFinal(failed) => _source == null ? _recoverPending : _run,
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
            maxLines: null,
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
                onPressed: _picking || _checkingPending
                    ? null
                    : short
                    ? () => context.router.push(RewardsRoute(scrollToEarn: true))
                    : _run,
              ),
            PrismButton(
              label: l10n.photoWallPickAnother,
              variant: mode == null ? PrismButtonVariant.primary : PrismButtonVariant.ghost,
              expand: true,
              maxLines: null,
              loading: _picking,
              onPressed: _pendingRequestId != null || _checkingPending ? null : _pick,
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
