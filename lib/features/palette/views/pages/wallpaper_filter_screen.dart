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
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/palette/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/palette/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
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
  bool _effectsAvailable = false;
  bool _comparing = false;
  bool _busy = false;
  bool _premiumFilterUnlockedForSession = false;

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

  void _toggleFilter(WallpaperFilter filter) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_stack.remove(filter)) {
        _stack.add(filter);
      }
    });
  }

  void _reset() {
    setState(() {
      _stack.clear();
      _adjustments = WallpaperAdjustments.none;
    });
  }

  Future<File> saveFilteredImage() async {
    if (!_isEdited) {
      return File(widget.filePath);
    }
    final ui.Codec codec = await ui.instantiateImageCodec(await File(widget.filePath).readAsBytes());
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      try {
        final Uint8List png = await renderEditedPng(frame.image, _stack, _adjustments);
        final String dir = (await getTemporaryDirectory()).path;
        final File file = File('$dir/prism_edit_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(png);
        return file;
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<void> _setBothWallPaper(String url) async {
    bool? result;
    try {
      result = await WallpaperService.setWallpaperFromSource(url, WallpaperTarget.both);
      if (result) {
        logger.d("Success");
        analytics.track(
          const SetWallEvent(wallpaperTarget: WallpaperTargetValue.both, result: BinaryResultValue.success),
        );
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      analytics.track(
        const SetWallEvent(wallpaperTarget: WallpaperTargetValue.both, result: BinaryResultValue.failure),
      );
      logger.d(e.toString());
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _setLockWallPaper(String url) async {
    bool? result;
    try {
      result = await WallpaperService.setWallpaperFromSource(url, WallpaperTarget.lock);
      if (result) {
        logger.d("Success");
        analytics.track(
          const SetWallEvent(wallpaperTarget: WallpaperTargetValue.lock, result: BinaryResultValue.success),
        );
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      logger.d(e.toString());
      analytics.track(
        const SetWallEvent(wallpaperTarget: WallpaperTargetValue.lock, result: BinaryResultValue.failure),
      );
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _setHomeWallPaper(String url) async {
    bool? result;
    try {
      result = await WallpaperService.setWallpaperFromSource(url, WallpaperTarget.home);
      if (result) {
        logger.d("Success");
        analytics.track(
          const SetWallEvent(wallpaperTarget: WallpaperTargetValue.home, result: BinaryResultValue.success),
        );
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      logger.d(e.toString());
      analytics.track(
        const SetWallEvent(wallpaperTarget: WallpaperTargetValue.home, result: BinaryResultValue.failure),
      );
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _runWithPremiumFilterGate(Future<void> Function() action, {required String sourceTag}) async {
    if (!_selectedFilterNeedsPremiumSpend || app_state.prismUser.premium || _premiumFilterUnlockedForSession) {
      await action();
      return;
    }

    if (!app_state.prismUser.loggedIn) {
      toasts.codeSend('Sign in to use premium filters with coins.');
      googleSignInPopUp(context, () {
        unawaited(_runWithPremiumFilterGate(action, sourceTag: '$sourceTag.after_sign_in'));
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
      toasts.codeSend('Premium filter unlocked for this edit (-${CoinPolicy.premiumFilter} coins).');
    }
    await action();
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
        await showModalBottomSheet<_PremiumFilterLowBalanceAction>(
          context: context,
          backgroundColor: Theme.of(context).primaryColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (sheetContext) {
            final int balance = CoinsService.instance.balanceNotifier.value;
            final int missing = (CoinPolicy.premiumFilter - balance).clamp(0, CoinPolicy.premiumFilter);
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
                  Text('Need Coins for Premium Filter', style: Theme.of(sheetContext).textTheme.displaySmall),
                  const SizedBox(height: 10),
                  Text(
                    'Applying this filter costs -5 coins. Need $missing more coins.',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(_PremiumFilterLowBalanceAction.watchAd),
                      child: const Text('Watch Ad (+10)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(_PremiumFilterLowBalanceAction.upgrade),
                      child: const Text('Upgrade to Pro'),
                    ),
                  ),
                ],
              ),
            );
          },
        ) ??
        _PremiumFilterLowBalanceAction.none;

    switch (action) {
      case _PremiumFilterLowBalanceAction.watchAd:
        await onWatchAd();
        return;
      case _PremiumFilterLowBalanceAction.upgrade:
        if (mounted) {
          await PaywallOrchestrator.instance.present(
            context,
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
    final bool watched = await _watchRewardedAd();
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
        await PaywallOrchestrator.instance.recordRewardedAdWatchAndMaybeUpsell(
          context,
          source: 'premium_filter_watch_ad',
        );
      }
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(sourceTag: '$sourceTag.rewarded_ad', error: error, stackTrace: stackTrace);
      toasts.error('Unable to credit coins right now.');
      return;
    }
    await _runWithPremiumFilterGate(action, sourceTag: '$sourceTag.retry');
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

  Future<void> _handleDownloadAction() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      toasts.codeSend("Processing Wallpaper");
      final imageFile = await saveFilteredImage();
      if (!mounted) {
        return;
      }
      final request = SaveMediaRequest(link: imageFile.path, isLocalFile: true, kind: SaveMediaKind.wallpaper);
      final result = await PrismMediaHostApi().saveMedia(request);
      if (result.success) {
        analytics.track(DownloadWallpaperEvent(link: imageFile.path));
        toasts.codeSend("Wall Saved in Pictures!");
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
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleSetAction() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final File imageFile;
    try {
      toasts.codeSend("Processing Wallpaper");
      imageFile = await saveFilteredImage();
    } catch (e) {
      logger.e('Unexpected filter render failure', error: e);
      toasts.error("Something went wrong!");
      return;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (!mounted) {
      return;
    }
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => SetOptionsPanel(
        onTap1: () {
          HapticFeedback.vibrate();
          Navigator.of(context).pop();
          _setHomeWallPaper(imageFile.path);
        },
        onTap2: () {
          HapticFeedback.vibrate();
          Navigator.of(context).pop();
          _setLockWallPaper(imageFile.path);
        },
        onTap3: () {
          HapticFeedback.vibrate();
          Navigator.of(context).pop();
          _setBothWallPaper(imageFile.path);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Wallpaper", style: theme.textTheme.displaySmall),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(JamIcons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: theme.primaryColor,
        actions: <Widget>[
          IconButton(tooltip: 'Reset', icon: const Icon(JamIcons.refresh), onPressed: _isEdited ? _reset : null),
          if (_busy)
            Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: theme.colorScheme.error)),
            )
          else
            IconButton(
              tooltip: 'Download',
              icon: const Icon(JamIcons.download),
              onPressed: () =>
                  unawaited(_runWithPremiumFilterGate(_handleDownloadAction, sourceTag: 'coins.filter.download')),
            ),
          if (!hideSetWallpaperUi)
            IconButton(
              tooltip: 'Set as wallpaper',
              icon: const Icon(JamIcons.check),
              onPressed: () => unawaited(_runWithPremiumFilterGate(_handleSetAction, sourceTag: 'coins.filter.set')),
            ),
        ],
      ),
      backgroundColor: theme.primaryColor,
      body: _loadFailed
          ? Center(child: Text("Couldn't open this wallpaper.", style: theme.textTheme.bodyMedium))
          : Column(
              children: [
                Expanded(child: _buildPreview(theme)),
                _buildBottomPanel(theme),
              ],
            ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final Size? size = _imageSize;
    if (size == null) {
      return Center(child: Loader());
    }
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: AspectRatio(
                aspectRatio: size.width / size.height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double shortSide = constraints.biggest.shortestSide;
                      final ui.ImageFilter? filter = _comparing
                          ? null
                          : buildEditFilter(_stack, _adjustments, shortSide);
                      Widget image = Image.file(
                        File(widget.filePath),
                        fit: BoxFit.cover,
                        cacheWidth: (constraints.maxWidth * dpr).round(),
                        gaplessPlayback: true,
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
                                  left: 10,
                                  top: 10,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Text(
                                        'Original',
                                        style: theme.textTheme.labelSmall!.copyWith(color: Colors.white),
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
          duration: const Duration(milliseconds: 150),
          opacity: _isEdited && !_comparing ? 1 : 0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Hold to compare',
              style: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.secondary.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(ThemeData theme) {
    final Color accent = theme.colorScheme.error;
    final Color muted = theme.colorScheme.secondary.withValues(alpha: 0.6);
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: 244 + MediaQuery.paddingOf(context).bottom,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: Column(
            children: [
              TabBar(
                indicatorColor: accent,
                labelColor: accent,
                unselectedLabelColor: muted,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Filters'),
                  Tab(text: 'Adjust'),
                ],
              ),
              Expanded(child: TabBarView(children: [_buildFiltersTab(theme), _buildAdjustTab(theme)])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersTab(ThemeData theme) {
    final List<Widget> tiles = <Widget>[
      _buildTile(
        theme,
        name: 'None',
        selected: _stack.isEmpty,
        order: 0,
        onTap: () => setState(_stack.clear),
        thumb: _thumb(),
      ),
      for (final ColorPreset preset in colorPresets)
        _buildTile(
          theme,
          name: preset.name,
          selected: _stack.contains(preset),
          order: _stack.indexOf(preset) + 1,
          onTap: () => _toggleFilter(preset),
          thumb: ColorFiltered(colorFilter: ColorFilter.matrix(preset.matrix), child: _thumb()),
        ),
      if (_effectsAvailable) ...[
        Center(child: Container(width: 1, height: 72, color: theme.colorScheme.secondary.withValues(alpha: 0.2))),
        for (final KernelEffect effect in kernelEffects)
          _buildTile(
            theme,
            name: effect.name,
            selected: _stack.contains(effect),
            order: _stack.indexOf(effect) + 1,
            onTap: () => _toggleFilter(effect),
            thumb: ImageFiltered(
              imageFilter: _kernelThumbFilters.putIfAbsent(effect, () => kernelImageFilter(effect)),
              child: _thumb(),
            ),
          ),
      ],
    ];
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(width: 4),
      itemBuilder: (_, index) => tiles[index],
    );
  }

  Widget _thumb() => Image(image: _thumbProvider, fit: BoxFit.cover);

  Widget _buildTile(
    ThemeData theme, {
    required String name,
    required bool selected,
    required int order,
    required VoidCallback onTap,
    required Widget thumb,
  }) {
    final Color accent = theme.colorScheme.error;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 64,
                    height: 92,
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? accent : Colors.transparent, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox.expand(child: thumb),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        child: _stack.length > 1
                            ? Text(
                                '$order',
                                style: theme.textTheme.labelSmall!.copyWith(color: Colors.white, fontSize: 10),
                              )
                            : const Icon(Icons.check, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustTab(ThemeData theme) {
    final WallpaperAdjustments a = _adjustments;
    String signed(double v) => v.round() > 0 ? '+${v.round()}' : '${v.round()}';
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _adjustRow(
          theme,
          icon: Icons.blur_on,
          label: 'Blur',
          value: a.blur * 100,
          min: 0,
          max: 100,
          text: '${(a.blur * 100).round()}',
          onChanged: (v) => _adjustments = a.copyWith(blur: v / 100),
          onReset: () => _adjustments = a.copyWith(blur: 0),
        ),
        _adjustRow(
          theme,
          icon: Icons.color_lens_outlined,
          label: 'Hue',
          value: a.hue,
          min: -180,
          max: 180,
          text: '${a.hue.round()}°',
          onChanged: (v) => _adjustments = a.copyWith(hue: v),
          onReset: () => _adjustments = a.copyWith(hue: 0),
        ),
        _adjustRow(
          theme,
          icon: JamIcons.water_drop,
          label: 'Saturation',
          value: a.saturation * 100,
          min: -100,
          max: 100,
          text: signed(a.saturation * 100),
          onChanged: (v) => _adjustments = a.copyWith(saturation: v / 100),
          onReset: () => _adjustments = a.copyWith(saturation: 0),
        ),
        _adjustRow(
          theme,
          icon: JamIcons.brightness,
          label: 'Brightness',
          value: a.brightness * 100,
          min: -100,
          max: 100,
          text: signed(a.brightness * 100),
          onChanged: (v) => _adjustments = a.copyWith(brightness: v / 100),
          onReset: () => _adjustments = a.copyWith(brightness: 0),
        ),
      ],
    );
  }

  Widget _adjustRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required String text,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
  }) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => setState(onReset),
          child: Row(
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.secondary),
              SizedBox(
                width: 84,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(label, style: theme.textTheme.bodyMedium),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: theme.colorScheme.error,
            inactiveColor: theme.colorScheme.secondary.withValues(alpha: 0.2),
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}
