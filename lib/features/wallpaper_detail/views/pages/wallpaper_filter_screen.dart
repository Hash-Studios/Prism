import 'dart:async';
import 'dart:io';

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
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/custom_filters.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as imagelib;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photofilters/filters/filters.dart';
import 'package:photofilters/filters/preset_filters.dart';

@RoutePage()
class WallpaperFilterScreen extends StatefulWidget {
  const WallpaperFilterScreen({
    super.key,
    required this.image,
    required this.finalImage,
    required this.filename,
    required this.finalFilename,
  });

  final imagelib.Image image;
  final imagelib.Image finalImage;
  final String filename;
  final String finalFilename;

  @override
  State<StatefulWidget> createState() => _WallpaperFilterScreenState();
}

enum _PremiumFilterLowBalanceAction { none, watchAd, upgrade }

class _WallpaperFilterScreenState extends State<WallpaperFilterScreen> {
  final Map<String, Uint8List> cachedFilters = {};
  Filter _filter = _filters.first;
  bool _busy = false;
  bool _premiumFilterUnlockedForSession = false;
  static final List<Filter> _filters = [
    NoFilter(),
    AddictiveBlueFilter(),
    AddictiveRedFilter(),
    AdenFilter(),
    AmaroFilter(),
    AshbyFilter(),
    BlurFilter(),
    BlurMaxFilter(),
    BrannanFilter(),
    BrooklynFilter(),
    CharmesFilter(),
    ClarendonFilter(),
    CremaFilter(),
    DogpatchFilter(),
    EarlybirdFilter(),
    EdgeDetectionFilter(),
    EmbossFilter(),
    F1977Filter(),
    GinghamFilter(),
    GinzaFilter(),
    HefeFilter(),
    HelenaFilter(),
    HighPassFilter(),
    HudsonFilter(),
    InkwellFilter(),
    InvertFilter(),
    JunoFilter(),
    KelvinFilter(),
    LarkFilter(),
    LoFiFilter(),
    LowPassFilter(),
    LudwigFilter(),
    MavenFilter(),
    MayfairFilter(),
    MeanFilter(),
    MoonFilter(),
    NashvilleFilter(),
    PerpetuaFilter(),
    ReyesFilter(),
    RiseFilter(),
    SharpenFilter(),
    SierraFilter(),
    SkylineFilter(),
    SlumberFilter(),
    StinsonFilter(),
    SutroFilter(),
    ToasterFilter(),
    ValenciaFilter(),
    VesperFilter(),
    WaldenFilter(),
    WillowFilter(),
    XProIIFilter(),
  ];

  Future<void> _setWallpaper(String path, WallpaperTarget target, WallpaperTargetValue analyticsTarget) async {
    try {
      final bool result = await WallpaperService.setWallpaperFromSource(path, target);
      if (result) {
        analytics.track(SetWallEvent(wallpaperTarget: analyticsTarget, result: BinaryResultValue.success));
        toasts.success("Wallpaper set successfully!");
      } else {
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      logger.e('Set wallpaper failed', error: e);
      analytics.track(SetWallEvent(wallpaperTarget: analyticsTarget, result: BinaryResultValue.failure));
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  bool get _selectedFilterNeedsPremiumSpend => _filter is! NoFilter;

  Future<void> _runWithPremiumFilterGate(Future<void> Function() action, {required String sourceTag}) async {
    if (!_selectedFilterNeedsPremiumSpend || app_state.prismUser.premium || _premiumFilterUnlockedForSession) {
      await action();
      return;
    }

    if (!app_state.prismUser.loggedIn) {
      toasts.success('Sign in to use premium filters with coins.');
      googleSignInPopUp(context, () {
        unawaited(_runWithPremiumFilterGate(action, sourceTag: '$sourceTag.after_sign_in'));
      });
      return;
    }

    analytics.track(CoinPremiumFilterSpendAttemptEvent(sourceTag: sourceTag, filter: _filter.name));

    CoinMutationResult spendResult;
    try {
      spendResult = await CoinsService.instance.spendForPremiumFilter(
        sourceTag: '$sourceTag.spend',
        reason: 'filter_${_filter.name}',
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
          filter: _filter.name,
        ),
      );
      toasts.success('Premium filter unlocked for this edit (-${CoinPolicy.premiumFilter} coins).');
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
    analytics.track(CoinFilterWatchAndRetryUsedEvent(sourceTag: sourceTag, filter: _filter.name));
    final bool watched = await watchRewardedAd(context.read<AdsBloc>());
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
    if (_busy) {
      return;
    }
    toasts.success("Processing Wallpaper");
    final imageFile = await saveFilteredImage();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = true;
    });
    final request = SaveMediaRequest(link: imageFile.path, isLocalFile: true, kind: SaveMediaKind.wallpaper);
    try {
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
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleSetAction() async {
    toasts.success("Processing Wallpaper");
    final imageFile = await saveFilteredImage();
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
          _setWallpaper(imageFile.path, WallpaperTarget.home, WallpaperTargetValue.home);
        },
        onTap2: () {
          HapticFeedback.vibrate();
          Navigator.of(context).pop();
          _setWallpaper(imageFile.path, WallpaperTarget.lock, WallpaperTargetValue.lock);
        },
        onTap3: () {
          HapticFeedback.vibrate();
          Navigator.of(context).pop();
          _setWallpaper(imageFile.path, WallpaperTarget.both, WallpaperTargetValue.both);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Wallpaper", style: Theme.of(context).textTheme.displaySmall),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(JamIcons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Theme.of(context).primaryColor,
        actions: <Widget>[
          if (_busy)
            Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.error),
              ),
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
      backgroundColor: Theme.of(context).primaryColor,
      body: SizedBox.expand(
        child: Column(
          children: [
            Expanded(flex: 6, child: SizedBox.expand(child: _buildFilteredImage())),
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: ColoredBox(
                color: Theme.of(context).primaryColor,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (BuildContext context, int index) {
                    return GestureDetector(
                      onTap: () => setState(() {
                        _filter = _filters[index];
                      }),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                _buildFilterThumbnail(_filters[index]),
                                if (_filter == _filters[index])
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(500),
                                      color: Colors.white,
                                    ),
                                    child: const Icon(JamIcons.check, color: Colors.black),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10.0),
                            Text(
                              _filters[index].name,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFrame(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 90.0,
        height: MediaQuery.of(context).size.height * 0.15,
        color: Theme.of(context).primaryColor,
        child: child,
      ),
    );
  }

  Widget _buildFilterThumbnail(Filter filter) {
    final Uint8List? cached = cachedFilters[filter.name];
    if (cached != null) {
      return _thumbFrame(Image(image: MemoryImage(cached), fit: BoxFit.cover));
    }
    return FutureBuilder<Uint8List>(
      future: compute(_applyFilter, (filter: filter, image: widget.image, filename: widget.filename)),
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _thumbFrame(Center(child: Loader()));
        }
        final Uint8List? bytes = snapshot.data;
        if (snapshot.hasError || bytes == null) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        cachedFilters[filter.name] = bytes;
        return _thumbFrame(Image(image: MemoryImage(bytes), fit: BoxFit.cover));
      },
    );
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/filtered_${_filter.name}_${widget.finalFilename}');
  }

  Future<File> saveFilteredImage() async {
    final imageFile = await _localFile;
    final Uint8List finalFilterImageBytes = await compute(_applyFilter, (
      filter: _filter,
      image: widget.finalImage,
      filename: widget.finalFilename,
    ));
    await imageFile.writeAsBytes(finalFilterImageBytes);
    return imageFile;
  }

  Widget _buildFilteredImage() {
    final Filter filter = _filter;
    return FutureBuilder<Uint8List>(
      future: compute(_applyFilter, (filter: filter, image: widget.finalImage, filename: widget.finalFilename)),
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          final Uint8List? cached = cachedFilters[filter.name];
          if (cached == null) return Center(child: Loader());
          return Stack(
            children: [
              PhotoView(
                imageProvider: MemoryImage(cached),
                backgroundDecoration: BoxDecoration(color: Theme.of(context).primaryColor),
              ),
              _progressOverlay(context),
            ],
          );
        }
        final Uint8List? bytes = snapshot.data;
        if (snapshot.hasError || bytes == null) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        cachedFilters[filter.name] = bytes;
        return PhotoView(
          imageProvider: MemoryImage(bytes),
          backgroundDecoration: BoxDecoration(color: Theme.of(context).primaryColor),
        );
      },
    );
  }

  Widget _progressOverlay(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool errorInvisible = context.isDarkMode && context.prismIsAmoledDark() && scheme.error == Colors.black;
    return Positioned(
      right: 10,
      top: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 25,
            width: 25,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(errorInvisible ? scheme.secondary : scheme.error),
            ),
          ),
          Icon(Icons.high_quality_rounded, color: scheme.secondary),
        ],
      ),
    );
  }
}

typedef _FilterJob = ({Filter filter, imagelib.Image image, String filename});

Uint8List _applyFilter(_FilterJob job) {
  final image = job.image;
  final Uint8List bytes = image.getBytes();
  job.filter.apply(bytes, image.width, image.height);
  final imagelib.Image filtered = imagelib.Image.fromBytes(image.width, image.height, bytes);
  return Uint8List.fromList(imagelib.encodeNamedImage(filtered, job.filename)!);
}
