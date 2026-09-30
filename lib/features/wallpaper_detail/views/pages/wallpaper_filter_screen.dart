import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/filter_editor_panel.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

@RoutePage()
class WallpaperFilterScreen extends StatefulWidget {
  const WallpaperFilterScreen({required this.filePath, super.key});

  final String filePath;

  @override
  State<StatefulWidget> createState() => _WallpaperFilterScreenState();
}

enum _PremiumFilterLowBalanceAction { none, watchAd, upgrade }

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
    HapticFeedback.selectionClick();
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

  Future<void> _setWallpaper(String path, WallpaperTarget target) async {
    try {
      final bool result = await WallpaperService.setWallpaperFromSource(path, target);
      if (result) {
        analytics.track(SetWallEvent(wallpaperTarget: target, result: BinaryResultValue.success));
        toasts.success("Wallpaper set successfully!");
      } else {
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      logger.e('Set wallpaper failed', error: e);
      analytics.track(SetWallEvent(wallpaperTarget: target, result: BinaryResultValue.failure));
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _runWithPremiumFilterGate(Future<void> Function() action, {required String sourceTag}) async {
    if (!mounted) return;
    if (!_selectedFilterNeedsPremiumSpend || app_state.prismUser.premium || _premiumFilterUnlockedForSession) {
      await action();
      return;
    }

    if (!app_state.prismUser.loggedIn) {
      toasts.success('Sign in to use premium filters with coins.');
      googleSignInPopUp(context, () {
        unawaited(_startActionWithPremiumFilterGate(action, sourceTag: '$sourceTag.after_sign_in'));
      });
      return;
    }

    analytics.track(CoinPremiumFilterSpendAttemptEvent(sourceTag: sourceTag, filter: _editLabel));

    CoinMutationResult spendResult;
    try {
      spendResult = await CoinsService.instance.spendForPremiumFilter(
        sourceTag: '$sourceTag.spend',
        reason: 'filter_$_editLabel',
      );
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(sourceTag: '$sourceTag.spend', error: error, stackTrace: stackTrace);
      toasts.error('Unable to process coins right now.');
      return;
    }
    if (!mounted) return;

    if (!spendResult.success) {
      if (spendResult.insufficientBalance) {
        await _showPremiumFilterLowBalanceNudge(
          sourceTag: '$sourceTag.low_balance_nudge',
          onWatchAd: () => _watchAdAndRetryPremiumFilter(action, sourceTag: '$sourceTag.watch_and_retry'),
        );
        return;
      }
      toasts.error('Unable to process coins right now.');
      return;
    }

    _premiumFilterUnlockedForSession = true;
    if (spendResult.changed) {
      analytics.track(
        CoinPremiumFilterSpendSuccessEvent(
          sourceTag: sourceTag,
          coinsSpent: CoinPolicy.premiumFilter,
          filter: _editLabel,
        ),
      );
      toasts.success('Premium filter unlocked for this edit (-${CoinPolicy.premiumFilter} coins).');
    }
    await action();
  }

  Future<void> _startActionWithPremiumFilterGate(Future<void> Function() action, {required String sourceTag}) async {
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

  Future<void> _showPremiumFilterLowBalanceNudge({
    required String sourceTag,
    required Future<void> Function() onWatchAd,
  }) async {
    if (!mounted) {
      return;
    }
    CoinsService.instance.logLowBalanceNudge(sourceTag: sourceTag, requiredCoins: CoinPolicy.premiumFilter);
    final _PremiumFilterLowBalanceAction action =
        await showCoinGateSheet<_PremiumFilterLowBalanceAction>(
          context,
          title: 'Need coins for premium filter',
          cost: CoinPolicy.premiumFilter,
          message: (missing) =>
              'Applying this filter costs ${CoinPolicy.premiumFilter} coins. You need $missing more coins.',
          options: const [
            CoinGateOption(
              label: 'Watch ad (+${CoinPolicy.rewardedAd})',
              value: _PremiumFilterLowBalanceAction.watchAd,
            ),
            CoinGateOption(label: 'Upgrade to Pro', value: _PremiumFilterLowBalanceAction.upgrade, outlined: true),
          ],
        ) ??
        _PremiumFilterLowBalanceAction.none;

    switch (action) {
      case _PremiumFilterLowBalanceAction.watchAd:
        await onWatchAd();
        return;
      case _PremiumFilterLowBalanceAction.upgrade:
        if (mounted) {
          await PaywallOrchestrator.instance.present(
            placement: PaywallPlacement.lowBalance,
            source: 'premium_filter_low_balance',
          );
        }
        return;
      case _PremiumFilterLowBalanceAction.none:
        return;
    }
  }

  Future<void> _watchAdAndRetryPremiumFilter(Future<void> Function() action, {required String sourceTag}) async {
    analytics.track(CoinFilterWatchAndRetryUsedEvent(sourceTag: sourceTag, filter: _editLabel));
    final bool watched = await watchRewardedAd(context.read<AdsBloc>());
    if (!mounted) return;
    if (!watched) {
      toasts.error('Ad was not completed.');
      return;
    }
    try {
      final credit = await CoinsService.instance.award(CoinEarnAction.rewardedAd, sourceTag: '$sourceTag.rewarded_ad');
      if (!credit.changed) {
        toasts.error('Unable to credit coins right now.');
        return;
      }
      if (mounted) {
        await PaywallOrchestrator.instance.recordRewardedAdWatchAndMaybeUpsell(source: 'premium_filter_watch_ad');
      }
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(sourceTag: '$sourceTag.rewarded_ad', error: error, stackTrace: stackTrace);
      toasts.error('Unable to credit coins right now.');
      return;
    }
    await _runWithPremiumFilterGate(action, sourceTag: '$sourceTag.retry');
  }

  Future<void> _handleDownloadAction() async {
    File? imageFile;
    try {
      toasts.success("Processing Wallpaper");
      imageFile = await saveFilteredImage();
      if (!mounted) {
        return;
      }
      final request = SaveMediaRequest(link: imageFile.path, isLocalFile: true, kind: SaveMediaKind.wallpaper);
      final result = await PrismMediaHostApi().saveMedia(request);
      if (result.success) {
        analytics.track(DownloadWallpaperEvent(link: imageFile.path));
        toasts.success("Wall Saved in Pictures!");
      } else {
        toasts.error("Couldn't save wallpaper. Please retry!");
      }
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        logger.w('saveMedia channel unavailable (native side not registered)', error: e);
      } else {
        logger.e('saveMedia failed', error: e);
      }
      toasts.error("Couldn't save wallpaper. Please retry!");
    } catch (e) {
      logger.e('Unexpected saveMedia failure', error: e);
      toasts.error("Something went wrong!");
    } finally {
      if (imageFile != null) await _deleteEditedFile(imageFile);
    }
  }

  Future<void> _handleSetAction() async {
    File? imageFile;
    try {
      toasts.success("Processing Wallpaper");
      imageFile = await saveFilteredImage();
    } catch (e) {
      logger.e('Unexpected filter render failure', error: e);
      toasts.error("Something went wrong!");
      return;
    }
    if (!mounted) {
      await _deleteEditedFile(imageFile);
      return;
    }
    try {
      final WallpaperTarget? target = await showPrismSheet<WallpaperTarget>(
        isScrollControlled: true,
        context: context,
        builder: (context) => SetOptionsPanel(
          onTap1: () {
            if (!mounted) return;
            HapticFeedback.vibrate();
            Navigator.of(context).pop(WallpaperTarget.home);
          },
          onTap2: () {
            if (!mounted) return;
            HapticFeedback.vibrate();
            Navigator.of(context).pop(WallpaperTarget.lock);
          },
          onTap3: () {
            if (!mounted) return;
            HapticFeedback.vibrate();
            Navigator.of(context).pop(WallpaperTarget.both);
          },
        ),
      );
      if (!mounted) return;
      switch (target) {
        case WallpaperTarget.home:
          await _setWallpaper(imageFile.path, WallpaperTarget.home);
        case WallpaperTarget.lock:
          await _setWallpaper(imageFile.path, WallpaperTarget.lock);
        case WallpaperTarget.both:
          await _setWallpaper(imageFile.path, WallpaperTarget.both);
        case null:
          return;
      }
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
        title: 'Edit wallpaper',
        onBack: () {
          if (!_busy) Navigator.pop(context);
        },
        actions: <Widget>[
          PrismIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Reset',
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
                    tooltip: 'Download',
                    onPressed: !_editorReady
                        ? null
                        : () => unawaited(
                            _startActionWithPremiumFilterGate(
                              _handleDownloadAction,
                              sourceTag: 'coins.filter.download',
                            ),
                          ),
                  ),
          ),
          if (!hideSetWallpaperUi)
            PrismIconButton(
              icon: Icons.check_rounded,
              tooltip: 'Set as wallpaper',
              onPressed: !_editorReady || _busy
                  ? null
                  : () => unawaited(_startActionWithPremiumFilterGate(_handleSetAction, sourceTag: 'coins.filter.set')),
            ),
        ],
        body: _loadFailed
            ? GlintState(
                kind: GlintStateKind.error,
                title: "Couldn't open this wallpaper",
                body: 'The file may have been moved or deleted.',
                actionLabel: 'Try again',
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
                      onAdjust: (value) => setState(() => _adjustments = value),
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
      return const GlintState(kind: GlintStateKind.loading, title: 'Loading image');
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
                                Positioned(
                                  left: PrismSpace.sm,
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
                                        'Original',
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
            child: Text('Hold to compare', style: PrismTextStyles.caption(context)),
          ),
        ),
      ],
    );
  }
}
