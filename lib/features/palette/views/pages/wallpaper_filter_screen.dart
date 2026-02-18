import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/palette/views/pages/custom_filters.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/globals.dart' as globals;
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
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photofilters/filters/filters.dart';
import 'package:photofilters/filters/preset_filters.dart';

@RoutePage()
class WallpaperFilterScreen extends StatefulWidget {
  final List<dynamic>? arguments;

  const WallpaperFilterScreen({
    super.key,
    this.arguments,
  });

  @override
  State<StatefulWidget> createState() => _WallpaperFilterScreenState();
}

enum _PremiumFilterLowBalanceAction {
  none,
  watchAd,
  upgrade,
}

class _WallpaperFilterScreenState extends State<WallpaperFilterScreen> {
  String? filename;
  String? finalFilename;
  Map<String, List<int>?> cachedFilters = {};
  Filter? _filter;
  imagelib.Image? image;
  imagelib.Image? finalImage;
  late bool loading;
  late bool isLoading;
  bool _premiumFilterUnlockedForSession = false;
  List<Filter> selectedFilters = [
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

  @override
  void initState() {
    super.initState();
    loading = false;
    isLoading = false;
    _filter = selectedFilters[0];
    final args = widget.arguments;
    image = args?[0] as imagelib.Image?;
    finalImage = args?[1] as imagelib.Image?;
    filename = args?[2] as String?;
    finalFilename = args?[3] as String?;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _setBothWallPaper(String url) async {
    bool? result;
    try {
      result = await WallpaperService.setWallpaperFromSource(
        url,
        WallpaperTarget.both,
      );
      if (result) {
        logger.d("Success");
        analytics.logEvent(name: 'set_wall', parameters: {'type': 'Both', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      analytics.logEvent(name: 'set_wall', parameters: {'type': 'Both', 'result': 'Failure'});
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
      result = await WallpaperService.setWallpaperFromSource(
        url,
        WallpaperTarget.lock,
      );
      if (result) {
        logger.d("Success");
        analytics.logEvent(name: 'set_wall', parameters: {'type': 'Lock', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      logger.d(e.toString());
      analytics.logEvent(name: 'set_wall', parameters: {'type': 'Lock', 'result': 'Failure'});
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _setHomeWallPaper(String url) async {
    bool? result;
    try {
      result = await WallpaperService.setWallpaperFromSource(
        url,
        WallpaperTarget.home,
      );
      if (result) {
        logger.d("Success");
        analytics.logEvent(name: 'set_wall', parameters: {'type': 'Home', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      logger.d(e.toString());
      analytics.logEvent(name: 'set_wall', parameters: {'type': 'Home', 'result': 'Failure'});
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  bool get _selectedFilterNeedsPremiumSpend => _filter != null && _filter is! NoFilter;

  Future<void> _runWithPremiumFilterGate(
    Future<void> Function() action, {
    required String sourceTag,
  }) async {
    if (!_selectedFilterNeedsPremiumSpend || globals.prismUser.premium || _premiumFilterUnlockedForSession) {
      await action();
      return;
    }

    if (!globals.prismUser.loggedIn) {
      toasts.codeSend('Sign in to use premium filters with coins.');
      googleSignInPopUp(context, () {
        unawaited(_runWithPremiumFilterGate(
          action,
          sourceTag: '$sourceTag.after_sign_in',
        ));
      });
      return;
    }

    analytics.logEvent(
      name: 'coin_premium_filter_spend_attempt',
      parameters: <String, Object>{
        'sourceTag': sourceTag,
        'filter': _filter?.name ?? '',
      },
    );

    CoinMutationResult spendResult;
    try {
      spendResult = await CoinsService.instance.spendForPremiumFilter(
        sourceTag: '$sourceTag.spend',
        reason: 'filter_${_filter?.name ?? ''}',
      );
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(
        sourceTag: '$sourceTag.spend',
        error: error,
        stackTrace: stackTrace,
      );
      toasts.error('Unable to process coins right now.');
      return;
    }

    if (!spendResult.success) {
      if (spendResult.insufficientBalance) {
        await _showPremiumFilterLowBalanceNudge(
          sourceTag: '$sourceTag.low_balance_nudge',
          onWatchAd: () => _watchAdAndRetryPremiumFilter(
            action,
            sourceTag: '$sourceTag.watch_and_retry',
          ),
        );
        return;
      }
      toasts.error('Unable to process coins right now.');
      return;
    }

    _premiumFilterUnlockedForSession = true;
    if (spendResult.changed) {
      analytics.logEvent(
        name: 'coin_premium_filter_spend_success',
        parameters: <String, Object>{
          'sourceTag': sourceTag,
          'coinsSpent': CoinPolicy.premiumFilter,
          'filter': _filter?.name ?? '',
        },
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
    CoinsService.instance.logLowBalanceNudge(
      sourceTag: sourceTag,
      requiredCoins: CoinPolicy.premiumFilter,
    );
    final _PremiumFilterLowBalanceAction action = await showModalBottomSheet<_PremiumFilterLowBalanceAction>(
          context: context,
          backgroundColor: Theme.of(context).primaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                  Text(
                    'Need Coins for Premium Filter',
                    style: Theme.of(sheetContext).textTheme.displaySmall,
                  ),
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
          context.router.push(const UpgradeRoute());
        }
        return;
      case _PremiumFilterLowBalanceAction.none:
        return;
    }
  }

  Future<void> _watchAdAndRetryPremiumFilter(
    Future<void> Function() action, {
    required String sourceTag,
  }) async {
    analytics.logEvent(
      name: 'coin_filter_watch_and_retry_used',
      parameters: <String, Object>{
        'sourceTag': sourceTag,
        'filter': _filter?.name ?? '',
      },
    );
    final bool watched = await _watchRewardedAd();
    if (!watched) {
      toasts.error('Ad was not completed.');
      return;
    }
    try {
      await CoinsService.instance.award(
        CoinEarnAction.rewardedAd,
        sourceTag: '$sourceTag.rewarded_ad',
      );
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(
        sourceTag: '$sourceTag.rewarded_ad',
        error: error,
        stackTrace: stackTrace,
      );
      toasts.error('Unable to credit coins right now.');
      return;
    }
    await _runWithPremiumFilterGate(
      action,
      sourceTag: '$sourceTag.retry',
    );
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
    try {
      final Future<AdsState> completion = bloc.stream
          .firstWhere(
            (state) => state.shouldUnlockDownload || state.actionStatus == ActionStatus.failure || state.ads.adFailed,
          )
          .timeout(const Duration(seconds: 60));
      bloc.add(const AdsEvent.watchAdRequested());
      final AdsState result = await completion;
      bloc.add(const AdsEvent.transientStateCleared());
      return result.shouldUnlockDownload;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleDownloadAction() async {
    if (isLoading || loading) {
      return;
    }
    toasts.codeSend("Processing Wallpaper");
    final imageFile = await saveFilteredImage();
    final status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      isLoading = true;
    });
    final request = SaveMediaRequest(
      link: imageFile.path,
      isLocalFile: true,
      kind: SaveMediaKind.wallpaper,
    );
    try {
      final result = await PrismMediaHostApi().saveMedia(request);
      if (result.success) {
        analytics.logEvent(name: 'download_wallpaper', parameters: {'link': imageFile.path});
        toasts.codeSend("Wall Saved in Pictures!");
      } else {
        toasts.error("Couldn't save wallpaper. Please retry!");
      }
    } on PlatformException catch (e) {
      logger.e('saveMedia failed', error: e);
      toasts.error("Couldn't save wallpaper. Please retry!");
    } catch (e) {
      logger.e('Unexpected saveMedia failure', error: e);
      toasts.error("Something went wrong!");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSetAction() async {
    if (loading) {
      return;
    }
    toasts.codeSend("Processing Wallpaper");
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Edit Wallpaper",
          style: Theme.of(context).textTheme.displaySmall,
        ),
        leading: IconButton(
            icon: const Icon(JamIcons.close),
            onPressed: () {
              Navigator.pop(context);
            }),
        backgroundColor: Theme.of(context).primaryColor,
        actions: <Widget>[
          if (loading)
            Container()
          else if (isLoading)
            Center(
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.error)),
            )
          else
            IconButton(
              icon: const Icon(JamIcons.download),
              onPressed: () => unawaited(
                _runWithPremiumFilterGate(
                  _handleDownloadAction,
                  sourceTag: 'coins.filter.download',
                ),
              ),
            ),
          if (loading)
            Container()
          else
            IconButton(
              icon: const Icon(JamIcons.check),
              onPressed: () => unawaited(
                _runWithPremiumFilterGate(
                  _handleSetAction,
                  sourceTag: 'coins.filter.set',
                ),
              ),
            )
        ],
      ),
      backgroundColor: Theme.of(context).primaryColor,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: loading
            ? Center(child: Loader())
            : Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: _buildFilteredImage(
                        _filter,
                        finalImage,
                        finalFilename,
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                  ),
                  Expanded(
                    flex: 2,
                    child: ColoredBox(
                      color: Theme.of(context).primaryColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedFilters.length,
                        itemBuilder: (BuildContext context, int index) {
                          return GestureDetector(
                            onTap: () => setState(() {
                              _filter = selectedFilters[index];
                            }),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      _buildFilterThumbnail(selectedFilters[index], image, filename),
                                      if (_filter == selectedFilters[index])
                                        Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(500),
                                              color: Colors.white,
                                            ),
                                            child: const Icon(
                                              JamIcons.check,
                                              color: Colors.black,
                                            ))
                                      else
                                        Container(),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10.0,
                                  ),
                                  Text(
                                    selectedFilters[index].name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(color: Theme.of(context).colorScheme.secondary),
                                  )
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

  Widget _buildFilterThumbnail(Filter filter, imagelib.Image? image, String? filename) {
    final String filterName = filter.name;
    if (cachedFilters[filterName] == null) {
      return FutureBuilder<List<int>>(
        future: compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": filename,
        }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.active:
            case ConnectionState.waiting:
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 90.0,
                  height: MediaQuery.of(context).size.height * 0.15,
                  color: Theme.of(context).primaryColor,
                  child: Center(
                    child: Loader(),
                  ),
                ),
              );
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              cachedFilters[filterName] = snapshot.data;
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 90.0,
                  height: MediaQuery.of(context).size.height * 0.15,
                  color: Theme.of(context).primaryColor,
                  child: Image(
                    image: MemoryImage(
                      (snapshot.data as Uint8List?)!,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              );
          }
        },
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 90.0,
          height: MediaQuery.of(context).size.height * 0.15,
          color: Theme.of(context).primaryColor,
          child: Image(
            image: MemoryImage(
              cachedFilters[filterName]! as Uint8List,
            ),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/filtered_${_filter?.name ?? "_"}_$finalFilename');
  }

  Future<File> saveFilteredImage() async {
    final imageFile = await _localFile;
    final List<int> finalFilterImageBytes = await compute(applyFilter, <String, dynamic>{
      "filter": _filter,
      "image": finalImage,
      "filename": finalFilename,
    });
    await imageFile.writeAsBytes(finalFilterImageBytes);
    return imageFile;
  }

  Widget _buildFilteredImage(Filter? filter, imagelib.Image? image, String? filename) {
    return FutureBuilder<List<int>>(
      future: compute(applyFilter, <String, dynamic>{
        "filter": filter,
        "image": image,
        "filename": filename,
      }),
      builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return cachedFilters[filter?.name ?? "_"] == null
                ? Center(child: Loader())
                : Stack(
                    children: [
                      PhotoView(
                        imageProvider: MemoryImage(
                          (cachedFilters[filter?.name ?? "_"] as Uint8List?)!,
                        ),
                        backgroundDecoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 25,
                              width: 25,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  context.prismModeStyleForContext() == "Dark" && context.prismIsAmoledDark()
                                      ? Theme.of(context).colorScheme.error == Colors.black
                                          ? Theme.of(context).colorScheme.secondary
                                          : Theme.of(context).colorScheme.error
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            Icon(Icons.high_quality_rounded, color: Theme.of(context).colorScheme.secondary),
                          ],
                        ),
                      ),
                    ],
                  );
          case ConnectionState.active:
          case ConnectionState.waiting:
            return cachedFilters[filter?.name ?? "_"] == null
                ? Center(child: Loader())
                : Stack(
                    children: [
                      PhotoView(
                        imageProvider: MemoryImage(
                          (cachedFilters[filter?.name ?? "_"] as Uint8List?)!,
                        ),
                        backgroundDecoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 25,
                              width: 25,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  context.prismModeStyleForContext() == "Dark" && context.prismIsAmoledDark()
                                      ? Theme.of(context).colorScheme.error == Colors.black
                                          ? Theme.of(context).colorScheme.secondary
                                          : Theme.of(context).colorScheme.error
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            Icon(Icons.high_quality_rounded, color: Theme.of(context).colorScheme.secondary),
                          ],
                        ),
                      ),
                    ],
                  );
          case ConnectionState.done:
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            cachedFilters[filter?.name ?? "_"] = snapshot.data;
            return PhotoView(
              imageProvider: MemoryImage(
                (snapshot.data as Uint8List?)!,
              ),
              backgroundDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            );
        }
      },
    );
  }
}

///The global applyfilter function
List<int> applyFilter(Map<String, dynamic> params) {
  final Filter? filter = params["filter"] as Filter?;
  final imagelib.Image image = params["image"] as imagelib.Image;
  final String filename = params["filename"] as String;
  List<int> bytes = image.getBytes();
  if (filter != null) {
    filter.apply(bytes as Uint8List, image.width, image.height);
  }
  final imagelib.Image image0 = imagelib.Image.fromBytes(image.width, image.height, bytes);

  return bytes = imagelib.encodeNamedImage(image0, filename)!;
}

///The global buildThumbnail function
List<int> buildThumbnail(Map<String, dynamic> params) {
  final int width = params["width"] as int;
  params["image"] = imagelib.copyResize(params["image"] as imagelib.Image, width: width);
  return applyFilter(params);
}
