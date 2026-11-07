import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/guest_browsing_policy.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/platform/wallpaper_set_feedback.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/crop_frame_view.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/filter_editor_panel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

@RoutePage()
class WallpaperFilterScreen extends StatefulWidget {
  const WallpaperFilterScreen({required this.filePath, this.guestShare = false, super.key});

  final String filePath;

  /// Set for an image shared to Prism from another app: a guest may crop it and set or save it. Premium filters
  /// still need an account.
  final bool guestShare;

  /// Renders the export. Tests replace it.
  @visibleForTesting
  static Future<Uint8List> Function(
    String path, {
    required List<WallpaperFilter> stack,
    required WallpaperAdjustments adjustments,
    CropSpec? crop,
    double? previewPixelShortSide,
    double deviceLongSidePx,
  })
  renderFile = renderEditedFile;

  /// How long the export may take. Tests shorten it.
  @visibleForTesting
  static Duration exportTimeLimit = editExportTimeLimit;

  /// Opens the system share sheet. Tests replace it.
  @visibleForTesting
  static Future<ShareResult> Function(ShareParams params) share = (params) => SharePlus.instance.share(params);

  @override
  State<StatefulWidget> createState() => _WallpaperFilterScreenState();
}

class _WallpaperFilterScreenState extends State<WallpaperFilterScreen> with SingleTickerProviderStateMixin {
  static const int _cropTab = 2;
  late final TabController _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
  CropSpec? _crop;
  int _sourceLoadGeneration = 0;
  bool _cropTabShown = false;
  final List<File> _sharedFiles = <File>[];
  final Set<String> _ownedExportDirectories = <String>{};
  final List<WallpaperFilter> _stack = <WallpaperFilter>[];
  WallpaperAdjustments _adjustments = WallpaperAdjustments.none;
  final Map<KernelEffect, ui.ImageFilter> _kernelThumbFilters = <KernelEffect, ui.ImageFilter>{};
  final Set<int> _sourceDecodeWidths = <int>{};
  ImageProvider get _thumbProvider => ResizeImage(FileImage(File(widget.filePath)), width: 160);
  Size? _imageSize;
  bool _loadFailed = false;
  bool _previewLoaded = false;
  bool _effectsAvailable = false;
  bool _comparing = false;
  bool _busy = false;
  bool _premiumFilterUnlockedForSession = false;
  double? _previewPixelsPerSourcePixel;
  Future<Uint8List>? _pendingRender;

  @override
  void dispose() {
    _tabs.dispose();
    for (final File file in _sharedFiles) {
      unawaited(_deleteEditedFile(file));
    }
    super.dispose();
  }

  void _onTabChanged() {
    final bool shown = _tabs.index == _cropTab;
    if (shown != _cropTabShown) setState(() => _cropTabShown = shown);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_readImageSize());
    unawaited(
      loadKernelEffects().then((available) {
        if (mounted) {
          setState(() => _effectsAvailable = available);
        }
      }),
    );
  }

  @override
  void didUpdateWidget(covariant WallpaperFilterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath == widget.filePath) return;
    _sourceLoadGeneration++;
    _sourceDecodeWidths.clear();
    setState(() {
      _crop = null;
      _imageSize = null;
      _loadFailed = false;
      _previewLoaded = false;
      _previewPixelsPerSourcePixel = null;
      _stack.clear();
      _adjustments = WallpaperAdjustments.none;
      _comparing = false;
    });
    unawaited(_readImageSize());
  }

  Future<void> _readImageSize() async {
    final int generation = ++_sourceLoadGeneration;
    final String path = widget.filePath;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (!mounted || generation != _sourceLoadGeneration) return;
      final int width = descriptor.width;
      final int height = descriptor.height;
      final Size screen = MediaQuery.sizeOf(context);
      setState(() {
        _imageSize = Size(width.toDouble(), height.toDouble());
        final CropSpec? crop = _crop;
        if (crop == null || crop.sourceWidth != width || crop.sourceHeight != height) {
          _crop = CropSpec.initial(sourceWidth: width, sourceHeight: height, phoneAspect: screen.width / screen.height);
        }
      });
    } catch (error, stackTrace) {
      if (generation != _sourceLoadGeneration) return;
      logger.w('Could not read wallpaper for editing', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _loadFailed = true);
      }
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  String get _editLabel => <String>[..._stack.map((f) => f.name), if (!_adjustments.isNone) 'Adjust'].join('+');

  bool get _isFiltered => _stack.isNotEmpty || !_adjustments.isNone;

  bool get _isCropped => !(_crop?.isIdentity ?? true);

  bool get _isEdited => _isFiltered || _isCropped;

  /// Filters and adjustments cost coins. A crop alone does not: the source already took the same grant as Download.
  bool get _selectedFilterNeedsPremiumSpend => _isFiltered;

  bool get _editorReady =>
      !_loadFailed && _previewLoaded && _previewPixelsPerSourcePixel != null && _pendingRender == null;

  void _toggleFilter(WallpaperFilter filter) {
    PrismHaptics.selection();
    setState(() {
      if (!_stack.remove(filter)) {
        _stack.add(filter);
      }
    });
  }

  Future<void> _retryLoad() async {
    final int generation = ++_sourceLoadGeneration;
    final String path = widget.filePath;
    final Set<int> decodeWidths = <int>{..._sourceDecodeWidths, 160};
    _sourceDecodeWidths.clear();
    setState(() {
      _loadFailed = false;
      _previewLoaded = false;
      _imageSize = null;
      _crop = null;
      _previewPixelsPerSourcePixel = null;
    });
    // A new Image widget key does not invalidate FileImage's path-based resized cache keys.
    await Future.wait(decodeWidths.map((width) => ResizeImage(FileImage(File(path)), width: width).evict()));
    if (!mounted || generation != _sourceLoadGeneration) return;
    await _readImageSize();
  }

  void _reset() {
    _resetCrop();
    setState(() {
      _stack.clear();
      _adjustments = WallpaperAdjustments.none;
    });
  }

  void _resetCrop() {
    final CropSpec? crop = _crop;
    if (crop == null || crop.isIdentity) return;
    analytics.track(WallpaperCropResetEvent(preset: crop.preset));
    setState(() => _crop = crop.reset());
  }

  void _pickCropPreset(CropPreset preset) {
    final CropSpec? crop = _crop;
    if (crop == null) return;
    setState(() => _crop = crop.withPreset(preset));
  }

  void _rotateCrop() {
    final CropSpec? crop = _crop;
    if (crop == null) return;
    PrismHaptics.selection();
    setState(() => _crop = crop.rotated());
  }

  void _trackCropApplied() {
    final CropSpec? crop = _crop;
    if (crop == null || crop.isIdentity) return;
    analytics.track(WallpaperCropAppliedEvent(preset: crop.preset, adjusted: crop.adjusted));
  }

  /// Writes the edit to a PNG in a temporary folder of its own and returns it, or the source when nothing changed.
  /// Throws [EditExportTimedOut] when the render runs past [WallpaperFilterScreen.exportTimeLimit].
  Future<File> saveFilteredImage() async {
    final String sourcePath = widget.filePath;
    final int sourceGeneration = _sourceLoadGeneration;
    bool sourceIsCurrent() => mounted && sourceGeneration == _sourceLoadGeneration;
    final List<WallpaperFilter> stack = List<WallpaperFilter>.of(_stack);
    final WallpaperAdjustments adjustments = _adjustments;
    final CropSpec? crop = _crop;
    final double? pixelsPerSourcePixel = _previewPixelsPerSourcePixel;
    final Size screenPixels = MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
    if (stack.isEmpty && adjustments.isNone && (crop == null || crop.isIdentity)) {
      return File(widget.filePath);
    }
    Future<Uint8List>? rendering = _pendingRender;
    if (rendering == null) {
      final Future<Uint8List> activeRender = WallpaperFilterScreen.renderFile(
        sourcePath,
        stack: stack,
        adjustments: adjustments,
        crop: crop,
        previewPixelShortSide: pixelsPerSourcePixel == null || crop == null
            ? null
            : math.min(crop.outputWidth, crop.outputHeight) * pixelsPerSourcePixel,
        deviceLongSidePx: screenPixels.longestSide,
      );
      rendering = activeRender;
      _pendingRender = activeRender;
      unawaited(
        activeRender.then<void>(
          (_) => _finishPendingRender(activeRender),
          onError: (Object _, StackTrace _) => _finishPendingRender(activeRender),
        ),
      );
    }
    final Future<Uint8List> activeRender = rendering;
    final Uint8List png = await withExportTimeLimit(activeRender, limit: WallpaperFilterScreen.exportTimeLimit);
    if (!sourceIsCurrent()) {
      throw StateError('Wallpaper editor closed before export completed');
    }
    final Directory exportBase = Directory('${(await getTemporaryDirectory()).path}/prism_edit');
    if (!sourceIsCurrent()) throw StateError('Wallpaper editor source changed before export completed');
    await exportBase.create(recursive: true);
    final Directory exportDirectory = await exportBase.createTemp('export_');
    _ownedExportDirectories.add(exportDirectory.path);
    if (!sourceIsCurrent()) {
      _ownedExportDirectories.remove(exportDirectory.path);
      await exportDirectory.delete(recursive: true);
      throw StateError('Wallpaper editor closed before export completed');
    }
    final File file = File('${exportDirectory.path}/edited.png');
    try {
      await file.writeAsBytes(png);
    } catch (_) {
      await _deleteEditedFile(file);
      rethrow;
    }
    if (!sourceIsCurrent()) {
      await _deleteEditedFile(file);
      throw StateError('Wallpaper editor closed before export completed');
    }
    return file;
  }

  void _finishPendingRender(Future<Uint8List> rendering) {
    if (!identical(_pendingRender, rendering)) return;
    _pendingRender = null;
    if (mounted) setState(() {});
  }

  Future<void> _deleteEditedFile(File file) async {
    if (!_ownedExportDirectories.remove(file.parent.path)) return;
    try {
      await file.parent.delete(recursive: true);
    } catch (_) {}
  }

  Future<WallpaperSetResult> _setWallpaper(String path, SetWallpaperChoice choice) async {
    final AppLocalizations l10n = context.l10n;
    final PlacedWallpaper? placed = choice.placed;
    final WallpaperSetResult result = await WallpaperService.setWallpaper(
      placed?.path ?? path,
      choice.target,
      useSystemCropper: placed == null && choice.useSystemCropper,
      recordHistory: false,
    );
    if (mounted) {
      try {
        reportWallpaperSetResult(
          context,
          result,
          l10n: l10n,
          target: choice.target,
          setContext: WallpaperSetContext(
            fit: placed == null ? WallpaperFit.fill.name : 'studio_${placed.placement.fit.name}',
            entryPoint: 'wallpaper_filter',
            targetChanged: choice.targetChanged,
          ),
        );
      } catch (error) {
        logger.w('Wallpaper set outcome follow-up failed', error: error);
      }
    }
    return result;
  }

  /// [action] is the export. It runs inside the coin gate and returns false when it failed, so the gate attempts a refund.
  Future<void> _runWithPremiumFilterGate(Future<bool> Function() action, {required String sourceTag}) async {
    final int sourceGeneration = _sourceLoadGeneration;
    bool sourceIsCurrent() => mounted && sourceGeneration == _sourceLoadGeneration;
    final bool freeGuestAction = widget.guestShare && guestBrowsingAllowed && !_selectedFilterNeedsPremiumSpend;
    if (!freeGuestAction && !await requireSignedInAction(context) || !mounted) return;
    if (!sourceIsCurrent()) return;
    final String owner = app_state.prismUser.id;
    if (!_selectedFilterNeedsPremiumSpend || app_state.prismUser.premium || _premiumFilterUnlockedForSession) {
      await action();
      return;
    }

    final String filter = _editLabel;
    // Spend tags end in `.spend`. The filter events log the tag without it.
    String eventTag(String spendTag) => spendTag.substring(0, spendTag.length - '.spend'.length);
    CoinGateSpec spec(String attemptSourceTag) {
      final String retryTag = '$attemptSourceTag.watch_and_retry';
      return CoinGateSpec(
        action: CoinSpendAction.premiumFilter,
        reason: 'filter_$filter',
        tags: CoinGateTags(
          spend: '$attemptSourceTag.spend',
          retrySpend: '$retryTag.retry.spend',
          ad: '$retryTag.rewarded_ad',
          insufficient: '$attemptSourceTag.low_balance_nudge',
        ),
        upsellSource: 'premium_filter_watch_ad',
        upgradeSource: 'premium_filter_low_balance',
        isMounted: () => sourceIsCurrent() && app_state.prismUser.loggedIn && owner == app_state.prismUser.id,
        perform: () => sourceIsCurrent() ? action() : Future<bool>.value(false),
        creditAfterUnmount: true,
        choose: _choosePremiumFilterAction,
        failureLabel: context.l10n.economyExportFailedLabel,
        refundReason: 'premium_filter_export_failed_refund',
        onAttempt: (spendTag) =>
            analytics.track(CoinPremiumFilterSpendAttemptEvent(sourceTag: eventTag(spendTag), filter: filter)),
        onWatchChosen: () => analytics.track(CoinFilterWatchAndRetryUsedEvent(sourceTag: retryTag, filter: filter)),
        onSpent: (spendTag, _) {
          analytics.track(
            CoinPremiumFilterSpendSuccessEvent(
              sourceTag: eventTag(spendTag),
              coinsSpent: CoinPolicy.premiumFilter,
              filter: filter,
            ),
          );
          toasts.success(context.l10n.wallpaperFilterUnlocked(CoinPolicy.premiumFilter));
        },
        retrySpec: () => spec('$retryTag.retry'),
      );
    }

    final CoinGateResult result = await CoinGate.forContext(context).run(spec(sourceTag));
    // A failed or refunded export must not leave the filter unlocked for the session.
    if (result == CoinGateResult.performed) {
      _premiumFilterUnlockedForSession = true;
    }
  }

  Future<void> _startActionWithPremiumFilterGate(Future<bool> Function() action, {required String sourceTag}) async {
    if (!mounted || _busy || !_editorReady) return;
    setState(() => _busy = true);
    try {
      await _runWithPremiumFilterGate(action, sourceTag: sourceTag);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<CoinGateChoice> _choosePremiumFilterAction(CoinGatePrompt prompt) async {
    final CoinGateChoice? choice = await showCoinGateSheet<CoinGateChoice>(
      context,
      title: context.l10n.wallpaperFilterNeedCoins,
      cost: CoinPolicy.premiumFilter,
      message: (missing) => context.l10n.wallpaperFilterApplyCost(CoinPolicy.premiumFilter, missing),
      options: [
        CoinGateOption(label: watchAdOptionLabel(context.l10n), value: CoinGateChoice.watchAd),
        CoinGateOption(label: context.l10n.wallpaperSeePrismPro, value: CoinGateChoice.upgrade, outlined: true),
      ],
    );
    return choice ?? CoinGateChoice.cancel;
  }

  bool get _mayAct => app_state.prismUser.loggedIn || (widget.guestShare && guestBrowsingAllowed);

  Future<bool> _handleDownloadAction() async {
    if (!mounted || !_mayAct) return false;
    final String owner = app_state.prismUser.id;
    final int sourceGeneration = _sourceLoadGeneration;
    final AppLocalizations l10n = context.l10n;
    File? imageFile;
    try {
      toasts.success(l10n.wallpaperProcessing, haptic: false);
      imageFile = await saveFilteredImage();
      if (!mounted || _sourceLoadGeneration != sourceGeneration || !_mayAct || owner != app_state.prismUser.id) {
        return false;
      }
      final request = SaveMediaRequest(link: imageFile.path, isLocalFile: true, kind: SaveMediaKind.wallpaper);
      final result = await PrismMediaHostApi().saveMedia(request);
      if (result.success) {
        try {
          _trackCropApplied();
          analytics.track(DownloadWallpaperEvent(link: imageFile.path));
          toasts.success(wallpaperSavedMessage(l10n));
          if (mounted) unawaited(showIosSetWallpaperGuide(context));
        } catch (error) {
          logger.w('Wallpaper saved but follow-up failed', error: error);
        }
        return true;
      }
      if (isPhotosPermissionDenied(result.errorCode) && mounted) {
        showPhotosPermissionDenied(context);
      } else {
        toasts.error(l10n.wallpaperFilterSaveError);
      }
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        logger.w('saveMedia channel unavailable (native side not registered)', error: e);
      } else {
        logger.e('saveMedia failed', error: e);
      }
      toasts.error(l10n.wallpaperFilterSaveError);
    } on EditExportTimedOut {
      toasts.error(l10n.wallpaperExportTimedOut);
    } catch (e) {
      logger.e('Unexpected saveMedia failure', error: e);
      toasts.error(l10n.wallpaperGenericError);
    } finally {
      if (imageFile != null) await _deleteEditedFile(imageFile);
    }
    return false;
  }

  /// Returns false when the render or the wallpaper set failed, or the account changed. Closing the target sheet is
  /// not a failure.
  Future<bool> _handleSetAction() async {
    if (!mounted || !_mayAct) return false;
    final String owner = app_state.prismUser.id;
    final int sourceGeneration = _sourceLoadGeneration;
    final AppLocalizations l10n = context.l10n;
    File? imageFile;
    try {
      toasts.success(l10n.wallpaperProcessing, haptic: false);
      imageFile = await saveFilteredImage();
    } on EditExportTimedOut {
      toasts.error(l10n.wallpaperExportTimedOut);
      return false;
    } catch (e) {
      logger.e('Unexpected filter render failure', error: e);
      toasts.error(l10n.wallpaperGenericError);
      return false;
    }
    if (!mounted || _sourceLoadGeneration != sourceGeneration || !_mayAct || owner != app_state.prismUser.id) {
      await _deleteEditedFile(imageFile);
      return false;
    }
    final String path = imageFile.path;
    SetWallpaperChoice? choice;
    try {
      choice = await SetWallpaperFlow.openScreen(
        context,
        SetScreenRequest(
          url: path,
          onAdjust: (screenContext) =>
              SetWallpaperFlow.openStudio(screenContext, url: path, entryPoint: 'wallpaper_filter'),
        ),
      );
      if (!mounted || _sourceLoadGeneration != sourceGeneration || !_mayAct || owner != app_state.prismUser.id) {
        return false;
      }
      if (choice == null) return true;
      final WallpaperSetResult result = await _setWallpaper(path, choice);
      if (!result.isFailure) _trackCropApplied();
      if (result.isSuccess || result.isInfo) {
        if (mounted) Navigator.of(context).pop();
      }
      return !result.isFailure;
    } finally {
      await choice?.placed?.discard();
      await _deleteEditedFile(imageFile);
    }
  }

  /// Shares the edited file. The file stays until the editor closes, because the receiving app may read it late.
  Future<bool> _handleShareAction() async {
    if (!mounted || !_mayAct) return false;
    final String owner = app_state.prismUser.id;
    final String sourcePath = widget.filePath;
    final int sourceGeneration = _sourceLoadGeneration;
    final AppLocalizations l10n = context.l10n;
    final RenderObject? box = context.findRenderObject();
    final Rect origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;
    File? imageFile;
    try {
      toasts.success(l10n.wallpaperProcessing, haptic: false);
      imageFile = await saveFilteredImage();
      if (!mounted || _sourceLoadGeneration != sourceGeneration || !_mayAct || owner != app_state.prismUser.id) {
        await _deleteEditedFile(imageFile);
        return false;
      }
      if (_ownedExportDirectories.contains(imageFile.parent.path)) _sharedFiles.add(imageFile);
      await WallpaperFilterScreen.share(
        ShareParams(
          files: <XFile>[XFile(imageFile.path, mimeType: imageFile.path == sourcePath ? 'image/*' : 'image/png')],
          sharePositionOrigin: origin.isEmpty ? const Rect.fromLTWH(1, 1, 1, 1) : origin,
        ),
      );
      _trackCropApplied();
      return true;
    } on EditExportTimedOut {
      toasts.error(l10n.wallpaperExportTimedOut);
    } catch (error, stackTrace) {
      logger.e('Could not share the edited wallpaper', error: error, stackTrace: stackTrace);
      toasts.error(l10n.wallpaperGenericError);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: PrismPage(
        title: context.l10n.wallpaperEditTitle,
        onBack: () {
          if (!_busy) Navigator.pop(context);
        },
        actions: <Widget>[
          PrismIconButton(
            icon: Icons.refresh_rounded,
            tooltip: context.l10n.wallpaperReset,
            onPressed: _isEdited && !_busy ? _reset : null,
          ),
          AnimatedSwitcher(
            duration: context.motion(PrismDurations.fast),
            child: _busy
                ? SizedBox.square(
                    key: const ValueKey('busy'),
                    dimension: 44,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                      ),
                    ),
                  )
                : PrismIconButton(
                    key: const ValueKey('download'),
                    icon: Icons.download_rounded,
                    tooltip: context.l10n.wallpaperDownload,
                    onPressed: !_editorReady
                        ? null
                        : () {
                            PrismHaptics.tap();
                            unawaited(
                              _startActionWithPremiumFilterGate(
                                _handleDownloadAction,
                                sourceTag: 'coins.filter.download',
                              ),
                            );
                          },
                  ),
          ),
          if (!widget.guestShare)
            PrismIconButton(
              icon: Icons.ios_share_rounded,
              tooltip: context.l10n.wallpaperShare,
              onPressed: !_editorReady || _busy
                  ? null
                  : () {
                      PrismHaptics.tap();
                      unawaited(_startActionWithPremiumFilterGate(_handleShareAction, sourceTag: 'coins.filter.share'));
                    },
            ),
          if (!hideSetWallpaperUi)
            PrismIconButton(
              icon: Icons.check_rounded,
              tooltip: context.l10n.wallpaperSetAsWallpaper,
              onPressed: !_editorReady || _busy
                  ? null
                  : () {
                      PrismHaptics.tap();
                      unawaited(_startActionWithPremiumFilterGate(_handleSetAction, sourceTag: 'coins.filter.set'));
                    },
            ),
        ],
        body: _loadFailed
            ? GlintState(
                kind: GlintStateKind.error,
                title: context.l10n.wallpaperOpenFileError,
                body: context.l10n.wallpaperFileMovedOrDeleted,
                actionLabel: context.l10n.wallpaperTryAgain,
                onAction: _retryLoad,
              )
            : Column(
                children: [
                  Expanded(child: _buildPreview(cs)),
                  IgnorePointer(
                    ignoring: _busy,
                    child: FilterEditorPanel(
                      controller: _tabs,
                      thumbProvider: _thumbProvider,
                      stack: _stack,
                      adjustments: _adjustments,
                      effectsAvailable: _effectsAvailable,
                      kernelThumbFilters: _kernelThumbFilters,
                      onClear: () => setState(_stack.clear),
                      onToggle: _toggleFilter,
                      onAdjust: (update) => setState(() => _adjustments = update(_adjustments)),
                      crop: _crop,
                      onCropPreset: _pickCropPreset,
                      onRotate: _rotateCrop,
                      onCropReset: _resetCrop,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    final CropSpec? crop = _crop;
    if (_imageSize == null || crop == null) {
      return GlintState(kind: GlintStateKind.loading, title: context.l10n.wallpaperLoadingImage);
    }
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.sm),
            child: _cropTabShown ? _buildCropFrame(crop, dpr) : _buildCroppedPreview(cs, crop, dpr),
          ),
        ),
        AnimatedOpacity(
          duration: context.motion(PrismDurations.fast),
          opacity: _isFiltered && !_comparing && !_cropTabShown ? 1 : 0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: PrismSpace.xs),
            child: Text(context.l10n.wallpaperFilterHoldToCompare, style: PrismTextStyles.caption(context)),
          ),
        ),
      ],
    );
  }

  /// Records how many screen pixels one source pixel takes in the preview, so the export draws effects at the size the
  /// user saw them.
  void _notePreviewScale(double pixelsPerSourcePixel) {
    if (_previewPixelsPerSourcePixel == pixelsPerSourcePixel) return;
    final int generation = _sourceLoadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _sourceLoadGeneration && _previewPixelsPerSourcePixel != pixelsPerSourcePixel) {
        setState(() => _previewPixelsPerSourcePixel = pixelsPerSourcePixel);
      }
    });
  }

  /// The source decoded at about the width it is drawn at, in steps of 256 pixels so small changes do not decode again.
  Widget _sourceImage(CropSpec crop, double drawnSourceWidthPx) {
    final int generation = _sourceLoadGeneration;
    final int needed = math.max(1, drawnSourceWidthPx.ceil());
    final int decodeWidth = math.min(crop.sourceWidth, ((needed + 255) ~/ 256) * 256);
    _sourceDecodeWidths.add(decodeWidth);
    return Image.file(
      File(widget.filePath),
      key: ValueKey<String>('${widget.filePath}:$_sourceLoadGeneration'),
      fit: BoxFit.fill,
      cacheWidth: decodeWidth,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, synchronous) {
        if (frame != null && !_previewLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && generation == _sourceLoadGeneration && !_previewLoaded) {
              setState(() => _previewLoaded = true);
            }
          });
        }
        return child;
      },
      errorBuilder: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _sourceLoadGeneration && !_loadFailed) {
            setState(() {
              _loadFailed = true;
              _previewLoaded = false;
            });
          }
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCropFrame(CropSpec crop, double dpr) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = CropFrameView.fitScale(crop, constraints.biggest);
        _notePreviewScale(scale * dpr);
        Widget image = _sourceImage(crop, crop.sourceWidth * scale * dpr);
        final double shortSide = math.min(crop.viewWidth, crop.viewHeight) * scale;
        final ui.ImageFilter? filter = shortSide > 0 ? buildEditFilter(_stack, _adjustments, shortSide) : null;
        if (filter != null) image = ImageFiltered(imageFilter: filter, child: image);
        return CropFrameView(spec: crop, image: image, onChanged: (next) => setState(() => _crop = next));
      },
    );
  }

  Widget _buildCroppedPreview(ColorScheme cs, CropSpec crop, double dpr) {
    return Center(
      child: AspectRatio(
        aspectRatio: crop.outputWidth / crop.outputHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PrismRadius.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double scale = constraints.maxWidth / crop.outputWidth;
              _notePreviewScale(scale * dpr);
              final double shortSide = constraints.biggest.shortestSide;
              final ui.ImageFilter? filter = _comparing ? null : buildEditFilter(_stack, _adjustments, shortSide);
              Widget image = ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Transform.translate(
                    offset: Offset(-crop.rect.left * scale, -crop.rect.top * scale),
                    child: SizedBox(
                      width: crop.viewWidth * scale,
                      height: crop.viewHeight * scale,
                      child: RotatedBox(
                        quarterTurns: crop.quarterTurns,
                        child: _sourceImage(crop, crop.sourceWidth * scale * dpr),
                      ),
                    ),
                  ),
                ),
              );
              if (filter != null) {
                image = ImageFiltered(imageFilter: filter, child: image);
              }
              return GestureDetector(
                onLongPressStart: (_) => setState(() => _comparing = true),
                onLongPressEnd: (_) => setState(() => _comparing = false),
                onLongPressCancel: () => setState(() => _comparing = false),
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      if (_comparing)
                        PositionedDirectional(
                          start: PrismSpace.sm,
                          top: PrismSpace.sm,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(PrismRadius.pill),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: PrismSpace.xxs),
                              child: Text(
                                context.l10n.wallpaperFilterOriginal,
                                style: PrismTextStyles.caption(
                                  context,
                                ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
