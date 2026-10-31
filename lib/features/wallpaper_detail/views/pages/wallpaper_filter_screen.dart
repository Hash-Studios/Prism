import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
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
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/filter_editor_panel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

@RoutePage()
class WallpaperFilterScreen extends StatefulWidget {
  const WallpaperFilterScreen({required this.filePath, super.key});

  final String filePath;

  @override
  State<StatefulWidget> createState() => _WallpaperFilterScreenState();
}

class _WallpaperFilterScreenState extends State<WallpaperFilterScreen> {
  final List<WallpaperFilter> _stack = <WallpaperFilter>[];
  WallpaperAdjustments _adjustments = WallpaperAdjustments.none;
  final Map<KernelEffect, ui.ImageFilter> _kernelThumbFilters = <KernelEffect, ui.ImageFilter>{};
  late final ImageProvider _thumbProvider = ResizeImage(FileImage(File(widget.filePath)), width: 160);
  Size? _imageSize;
  bool _loadFailed = false;
  bool _previewLoaded = false;
  bool _effectsAvailable = false;
  bool _comparing = false;
  bool _busy = false;
  bool _premiumFilterUnlockedForSession = false;
  double? _previewPixelShortSide;

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

  Future<void> _readImageSize() async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      final Uint8List bytes = await File(widget.filePath).readAsBytes();
      if (!mounted) return;
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (!mounted) {
        return;
      }
      setState(() {
        _imageSize = Size(descriptor!.width.toDouble(), descriptor.height.toDouble());
      });
    } catch (error, stackTrace) {
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

  bool get _isEdited => _stack.isNotEmpty || !_adjustments.isNone;

  bool get _selectedFilterNeedsPremiumSpend => _isEdited;

  bool get _editorReady => !_loadFailed && _previewLoaded && _previewPixelShortSide != null;

  void _toggleFilter(WallpaperFilter filter) {
    PrismHaptics.selection();
    setState(() {
      if (!_stack.remove(filter)) {
        _stack.add(filter);
      }
    });
  }

  void _retryLoad() {
    setState(() {
      _loadFailed = false;
      _previewLoaded = false;
      _imageSize = null;
    });
    unawaited(_readImageSize());
  }

  void _reset() {
    setState(() {
      _stack.clear();
      _adjustments = WallpaperAdjustments.none;
    });
  }

  Future<File> saveFilteredImage() async {
    final List<WallpaperFilter> stack = List<WallpaperFilter>.of(_stack);
    final WallpaperAdjustments adjustments = _adjustments;
    final double? previewPixelShortSide = _previewPixelShortSide;
    final Size screenPixels = MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
    if (stack.isEmpty && adjustments.isNone) {
      return File(widget.filePath);
    }
    final ui.Codec codec = await ui.instantiateImageCodec(await File(widget.filePath).readAsBytes());
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      try {
        final Uint8List png = await renderEditedPng(
          frame.image,
          stack,
          adjustments,
          previewPixelShortSide: previewPixelShortSide,
          deviceLongSidePx: screenPixels.longestSide,
        );
        if (!mounted) {
          throw StateError('Wallpaper editor closed before export completed');
        }
        final Directory exportBase = Directory('${(await getTemporaryDirectory()).path}/prism_edit');
        await exportBase.create(recursive: true);
        final Directory exportDirectory = await exportBase.createTemp('export_');
        if (!mounted) {
          await exportDirectory.delete(recursive: true);
          throw StateError('Wallpaper editor closed before export completed');
        }
        final File file = File('${exportDirectory.path}/edited.png');
        try {
          await file.writeAsBytes(png);
        } catch (_) {
          await exportDirectory.delete(recursive: true);
          rethrow;
        }
        if (!mounted) {
          await exportDirectory.delete(recursive: true);
          throw StateError('Wallpaper editor closed before export completed');
        }
        return file;
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<void> _deleteEditedFile(File file) async {
    if (file.path == widget.filePath) return;
    try {
      await file.parent.delete(recursive: true);
    } catch (_) {}
  }

  Future<WallpaperSetResult> _setWallpaper(String path, SetWallpaperChoice choice) async {
    final AppLocalizations l10n = context.l10n;
    final WallpaperSetResult result = await WallpaperService.setWallpaper(
      path,
      choice.target,
      useSystemCropper: choice.useSystemCropper,
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
            fit: WallpaperFit.fill.name,
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
    if (!await requireSignedInAction(context) || !mounted) return;
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
        isMounted: () => mounted && app_state.prismUser.loggedIn && owner == app_state.prismUser.id,
        perform: action,
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

  Future<bool> _handleDownloadAction() async {
    if (!await requireSignedInAction(context) || !mounted) return false;
    final String owner = app_state.prismUser.id;
    final AppLocalizations l10n = context.l10n;
    File? imageFile;
    try {
      toasts.success(l10n.wallpaperProcessing, haptic: false);
      imageFile = await saveFilteredImage();
      if (!mounted || !app_state.prismUser.loggedIn || owner != app_state.prismUser.id) {
        return false;
      }
      final request = SaveMediaRequest(link: imageFile.path, isLocalFile: true, kind: SaveMediaKind.wallpaper);
      final result = await PrismMediaHostApi().saveMedia(request);
      if (result.success) {
        try {
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
    if (!await requireSignedInAction(context) || !mounted) return false;
    final String owner = app_state.prismUser.id;
    final AppLocalizations l10n = context.l10n;
    File? imageFile;
    try {
      toasts.success(l10n.wallpaperProcessing, haptic: false);
      imageFile = await saveFilteredImage();
    } catch (e) {
      logger.e('Unexpected filter render failure', error: e);
      toasts.error(l10n.wallpaperGenericError);
      return false;
    }
    if (!mounted || !app_state.prismUser.loggedIn || owner != app_state.prismUser.id) {
      await _deleteEditedFile(imageFile);
      return false;
    }
    try {
      final SetWallpaperChoice? choice = await SetWallpaperFlow.openScreen(
        context,
        SetScreenRequest(url: imageFile.path),
      );
      if (!mounted || !app_state.prismUser.loggedIn || owner != app_state.prismUser.id) return false;
      if (choice == null) return true;
      final WallpaperSetResult result = await _setWallpaper(imageFile.path, choice);
      if (result.isSuccess || result.isInfo) {
        if (mounted) Navigator.of(context).pop();
      }
      return !result.isFailure;
    } finally {
      await _deleteEditedFile(imageFile);
    }
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
                      thumbProvider: _thumbProvider,
                      stack: _stack,
                      adjustments: _adjustments,
                      effectsAvailable: _effectsAvailable,
                      kernelThumbFilters: _kernelThumbFilters,
                      onClear: () => setState(_stack.clear),
                      onToggle: _toggleFilter,
                      onAdjust: (update) => setState(() => _adjustments = update(_adjustments)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    final Size? size = _imageSize;
    if (size == null) {
      return GlintState(kind: GlintStateKind.loading, title: context.l10n.wallpaperLoadingImage);
    }
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.sm),
            child: Center(
              child: AspectRatio(
                aspectRatio: size.width / size.height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double shortSide = constraints.biggest.shortestSide;
                      final double pixelShortSide = shortSide * dpr;
                      if (_previewPixelShortSide != pixelShortSide) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _previewPixelShortSide != pixelShortSide) {
                            setState(() => _previewPixelShortSide = pixelShortSide);
                          }
                        });
                      }
                      final ui.ImageFilter? filter = _comparing
                          ? null
                          : buildEditFilter(_stack, _adjustments, shortSide);
                      Widget image = Image.file(
                        File(widget.filePath),
                        fit: BoxFit.cover,
                        cacheWidth: (constraints.maxWidth * dpr).round(),
                        gaplessPlayback: true,
                        frameBuilder: (context, child, frame, synchronous) {
                          if (frame != null && !_previewLoaded) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_previewLoaded) setState(() => _previewLoaded = true);
                            });
                          }
                          return child;
                        },
                        errorBuilder: (_, _, _) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_loadFailed) {
                              setState(() {
                                _loadFailed = true;
                                _previewLoaded = false;
                              });
                            }
                          });
                          return const SizedBox.shrink();
                        },
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: PrismSpace.xs,
                                        vertical: PrismSpace.xxs,
                                      ),
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
            ),
          ),
        ),
        AnimatedOpacity(
          duration: context.motion(PrismDurations.fast),
          opacity: _isEdited && !_comparing ? 1 : 0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: PrismSpace.xs),
            child: Text(context.l10n.wallpaperFilterHoldToCompare, style: PrismTextStyles.caption(context)),
          ),
        ),
      ],
    );
  }
}
