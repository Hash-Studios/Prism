import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/core/widgets/home/core/colorBar.dart';
import 'package:Prism/core/widgets/menuButton/editButton.dart';
import 'package:Prism/core/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/core/widgets/menuButton/shareButton.dart';
import 'package:Prism/data/informatics/dataManager.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as data;
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart' as wdata;
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/palette/palette.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

@RoutePage()
class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key, required this.source, required this.link, this.index, this.item, this.wotdWall})
    : assert(
        source == WallpaperSource.wallOfTheDay ? wotdWall != null : (item != null || index != null),
        'WallOfTheDay requires wotdWall. Other providers require item or index.',
      );

  final WallpaperSource source;
  final int? index;
  final String link;
  final FeedItemEntity? item;
  final WallOfTheDayEntity? wotdWall;

  @override
  _WallpaperScreenState createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> with SingleTickerProviderStateMixin {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  late WallpaperSource source;
  late int index;
  late String link;
  WallOfTheDayEntity? _wotdWall;
  late AnimationController shakeController;
  List<Color?>? colors;
  Color? accent = Colors.white;
  bool colorChanged = false;
  late File _imageFile;
  bool screenshotTaken = false;
  ScreenshotController screenshotController = ScreenshotController();
  PanelController panelController = PanelController();
  bool panelClosed = true;
  bool panelCollapsed = true;
  Future<String>? _futureView;
  int firstTime = 0;
  bool _panelScrollInProgress = false;

  String get _sourceContext => '${source.wireValue}_wallpaper_screen';

  PrismFeedItem? get _prismFeedItem => widget.item is PrismFeedItem ? widget.item as PrismFeedItem? : null;
  WallhavenFeedItem? get _wallhavenFeedItem =>
      widget.item is WallhavenFeedItem ? widget.item as WallhavenFeedItem? : null;
  PexelsFeedItem? get _pexelsFeedItem => widget.item is PexelsFeedItem ? widget.item as PexelsFeedItem? : null;

  PrismWallpaper get _prismWall {
    if (_wotdWall case final entity?) {
      return PrismWallpaper.fromWotd(entity);
    }
    if (_prismFeedItem != null) {
      return _prismFeedItem!.wallpaper;
    }
    return data.subPrismWalls![index];
  }

  WallhavenWallpaper get _wallhavenWall {
    final typed = _wallhavenFeedItem?.wallpaper;
    if (typed == null) {
      return wdata.walls[index];
    }
    return typed;
  }

  PexelsWallpaper get _pexelsWall {
    final typed = _pexelsFeedItem?.wallpaper;
    if (typed == null) {
      return pdata.wallsP[index];
    }
    return typed;
  }

  String? _currentItemId() {
    try {
      if (source == WallpaperSource.prism || source == WallpaperSource.wallOfTheDay) {
        return _prismWall.id;
      }
      if (source == WallpaperSource.wallhaven) {
        return _wallhavenWall.id;
      }
      if (source == WallpaperSource.pexels) {
        return _pexelsWall.id;
      }
    } catch (_) {}
    return null;
  }

  void _trackAction(AnalyticsActionValue action) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.wallpaperScreen,
          action: action,
          sourceContext: _sourceContext,
          itemType: ItemTypeValue.wallpaper,
          itemId: _currentItemId(),
          index: index,
        ),
      ),
    );
  }

  void _updatePaletteGenerator() {
    _contentLoadTracker.start();
    context.read<PaletteBloc>().add(PaletteEvent.paletteRequested(imageUrl: link));
  }

  void _applyPaletteState(PaletteState state) {
    if (!mounted) return;
    if (state.status == LoadStatus.failure) {
      _contentLoadTracker.failure(
        reason: AnalyticsReasonValue.error,
        onFailure: ({required int loadTimeMs, AnalyticsReasonValue? reason, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.wallpaperScreen,
              result: EventResultValue.failure,
              loadTimeMs: loadTimeMs,
              sourceContext: _sourceContext,
              reason: reason,
            ),
          );
        },
      );
      return;
    }
    if (state.status != LoadStatus.success || state.palette.paletteColorValues.isEmpty) {
      return;
    }

    final paletteColors = state.palette.paletteColorValues.map((colorValue) => Color(colorValue)).toList();
    final limitedColors = paletteColors.length > 5 ? paletteColors.sublist(0, 5) : paletteColors;

    setState(() {
      colors = limitedColors;
      accent = limitedColors[0];
    });

    _contentLoadTracker.success(
      itemCount: limitedColors.length,
      onSuccess: ({required int loadTimeMs, int? itemCount}) async {
        await analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.wallpaperScreen,
            result: EventResultValue.success,
            loadTimeMs: loadTimeMs,
            sourceContext: _sourceContext,
            itemCount: itemCount,
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 500)).then((_) {
      if (!mounted || accent == null) return;
      _setStatusBarIconBrightness(accent!);
    });
  }

  void _setStatusBarIconBrightness(Color color) {
    if (color.computeLuminance() > 0.5) {
      applyEdgeToEdgeOverlayStyle(statusBarIconBrightness: Brightness.dark);
    } else {
      applyEdgeToEdgeOverlayStyle(statusBarIconBrightness: Brightness.light);
    }
  }

  void updateAccent() {
    if (colors!.contains(accent)) {
      final index = colors!.indexOf(accent);
      setState(() {
        accent = colors![(index + 1) % 5];
      });
      setState(() {
        colorChanged = true;
      });
      _setStatusBarIconBrightness(accent!);
    }
    _trackAction(AnalyticsActionValue.paletteCycleTapped);
    if (firstTime == 0) {
      toasts.codeSend("Long press to reset.");
      firstTime = 1;
    }
  }

  @override
  void initState() {
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    super.initState();
    source = widget.source;
    if (source == WallpaperSource.wallOfTheDay) {
      _wotdWall = widget.wotdWall;
      index = 0;
    } else {
      index = widget.index ?? 0;
    }
    link = widget.link;
    _contentLoadTracker.start();
    if (source == WallpaperSource.prism) {
      updateViews(_prismWall.id.toUpperCase());
      _futureView = getViews(_prismWall.id.toUpperCase());
    } else if (source == WallpaperSource.wallOfTheDay) {
      _futureView = Future.value('0');
    }
    Future.delayed(Duration.zero).then((value) => _updatePaletteGenerator());
  }

  @override
  void dispose() {
    super.dispose();
    shakeController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paletteState = context.watch<PaletteBloc>().state;
    final paletteLoading = paletteState.status == LoadStatus.loading || paletteState.status == LoadStatus.initial;
    final Animation<double> offsetAnimation =
        Tween(begin: 0.0, end: 48.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    return BlocListener<PaletteBloc, PaletteState>(
      listenWhen: (previous, current) => previous.status != current.status || previous.palette != current.palette,
      listener: (context, state) => _applyPaletteState(state),
      child: source == WallpaperSource.wallhaven
          ? Scaffold(
              key: _scaffoldKey,
              backgroundColor: paletteLoading ? Theme.of(context).primaryColor : accent,
              body: SlidingUpPanel(
                onPanelOpened: () {
                  _trackAction(AnalyticsActionValue.panelOpened);
                  setState(() {
                    panelCollapsed = false;
                  });
                  setState(() {
                    panelCollapsed = false;
                  });
                  if (panelClosed) {
                    logger.d('Screenshot Starting');
                    setState(() {
                      panelClosed = false;
                    });
                    if (colorChanged) {
                      screenshotController
                          .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                          .then((Uint8List? image) async {
                            setState(() {
                              _imageFile = File.fromRawPath(image!);
                              screenshotTaken = true;
                            });
                            logger.d('Screenshot Taken');
                          })
                          .catchError((onError) {
                            logger.d(onError as String);
                          });
                    } else {
                      _settingsLocal.get<bool>('optimisedWallpapers', defaultValue: false) == true
                          ? screenshotController
                                .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                                .then((Uint8List? image) async {
                                  setState(() {
                                    _imageFile = File.fromRawPath(image!);
                                    screenshotTaken = true;
                                  });
                                  logger.d('Screenshot Taken');
                                })
                                .catchError((onError) {
                                  logger.d(onError.toString());
                                })
                          : logger.d("Wallpaper Optimisation is disabled!");
                    }
                  }
                },
                onPanelClosed: () {
                  _trackAction(AnalyticsActionValue.panelClosed);
                  setState(() {
                    panelCollapsed = true;
                  });
                  setState(() {
                    panelClosed = true;
                  });
                },
                backdropEnabled: true,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                boxShadow: const [],
                collapsed: CollapsedPanel(panelCollapsed: panelCollapsed, panelController: panelController),
                minHeight: MediaQuery.of(context).size.height / 20,
                parallaxEnabled: true,
                parallaxOffset: 0.00,
                color: Colors.transparent,
                maxHeight: MediaQuery.of(context).size.height * .43,
                controller: panelController,
                panel: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  height: MediaQuery.of(context).size.height * .43,
                  width: MediaQuery.of(context).size.width,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 750),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: panelCollapsed
                              ? Theme.of(context).primaryColor.withValues(alpha: 1)
                              : Theme.of(context).primaryColor.withValues(alpha: .5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: AnimatedOpacity(
                                  duration: Duration.zero,
                                  opacity: panelCollapsed ? 0.0 : 1.0,
                                  child: GestureDetector(
                                    onTap: () {
                                      _trackAction(AnalyticsActionValue.panelCollapseTapped);
                                      panelController.close();
                                    },
                                    child: Icon(JamIcons.chevron_down, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                ),
                              ),
                            ),
                            ColorBar(colors: colors, fixedHeight: 64),
                            Expanded(
                              flex: 8,
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                            child: Text(
                                              _wallhavenWall.id.toUpperCase(),
                                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                color: Theme.of(context).colorScheme.secondary,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                JamIcons.eye,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                _wallhavenWall.views.toString(),
                                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Icon(
                                                JamIcons.heart_f,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                _wallhavenWall.core.favourites?.toString() ?? '0',
                                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Icon(
                                                JamIcons.save,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                "${double.parse((double.parse(_wallhavenWall.core.sizeBytes?.toString() ?? '0') / 1000000).toString()).toStringAsFixed(2)} MB",
                                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: <Widget>[
                                          Padding(
                                            padding: EdgeInsets.zero,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    (_wallhavenWall.core.category?.toString()[0].toUpperCase() ?? '') +
                                                        (_wallhavenWall.core.category?.toString().substring(1) ?? ''),
                                                    overflow: TextOverflow.ellipsis,
                                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Icon(
                                                  JamIcons.unordered_list,
                                                  size: 20,
                                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  _wallhavenWall.core.resolution?.toString() ?? '',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                    color: Theme.of(context).colorScheme.secondary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                JamIcons.set_square,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  source.legacyProviderString,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                    color: Theme.of(context).colorScheme.secondary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                JamIcons.database,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  DownloadButton(
                                    colorChanged: colorChanged,
                                    link: screenshotTaken ? _imageFile.path : _wallhavenWall.core.fullUrl,
                                  ),
                                  if (!hideSetWallpaperUi)
                                    SetWallpaperButton(
                                      colorChanged: colorChanged,
                                      url: screenshotTaken ? _imageFile.path : _wallhavenWall.core.fullUrl,
                                    ),
                                  FavouriteWallpaperButton(
                                    wall: WallhavenFavouriteWall(id: _wallhavenWall.id, wallpaper: _wallhavenWall),
                                    trash: false,
                                  ),
                                  ShareButton(
                                    id: _wallhavenWall.id,
                                    source: source,
                                    url: _wallhavenWall.core.fullUrl,
                                    thumbUrl: _wallhavenWall.core.thumbnailUrl,
                                  ),
                                  EditButton(url: _wallhavenWall.core.fullUrl),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                body: Stack(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: offsetAnimation,
                      builder: (buildContext, child) {
                        if (offsetAnimation.value < 0.0) {
                          logger.d('${offsetAnimation.value + 8.0}');
                        }
                        return GestureDetector(
                          onPanUpdate: (details) {
                            if (details.delta.dy < -10) {
                              panelController.open();
                            }
                          },
                          onLongPress: () {
                            _trackAction(AnalyticsActionValue.paletteResetLongPressed);
                            setState(() {
                              colorChanged = false;
                            });
                            HapticFeedback.vibrate();
                            shakeController.forward(from: 0.0);
                          },
                          onTap: () {
                            HapticFeedback.vibrate();
                            !paletteLoading ? updateAccent() : logger.d("");
                            shakeController.forward(from: 0.0);
                          },
                          child: CachedNetworkImage(
                            imageUrl: _wallhavenWall.core.thumbnailUrl,
                            imageBuilder: (context, imageProvider) => Screenshot(
                              controller: screenshotController,
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  vertical: offsetAnimation.value * 1.25,
                                  horizontal: offsetAnimation.value / 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(offsetAnimation.value),
                                  image: DecorationImage(
                                    colorFilter: colorChanged ? ColorFilter.mode(accent!, BlendMode.hue) : null,
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                              children: <Widget>[
                                const SizedBox.expand(child: Text("")),
                                Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                                    value: downloadProgress.progress,
                                  ),
                                ),
                              ],
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                JamIcons.close_circle_f,
                                color: paletteLoading
                                    ? Theme.of(context).colorScheme.secondary
                                    : accent!.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.backTapped);
                            Navigator.pop(context);
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.chevron_left),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.clockOverlayOpened);
                            final link = _wallhavenWall.core.fullUrl;
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) {
                                  animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ClockOverlay(
                                      colorChanged: colorChanged,
                                      accent: accent,
                                      link: link,
                                      file: false,
                                    ),
                                  );
                                },
                                fullscreenDialog: true,
                                opaque: false,
                              ),
                            );
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.clock),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : source == WallpaperSource.prism || source == WallpaperSource.wallOfTheDay
          ? Scaffold(
              key: _scaffoldKey,
              backgroundColor: paletteLoading ? Theme.of(context).primaryColor : accent,
              body: SlidingUpPanel(
                onPanelOpened: () {
                  _trackAction(AnalyticsActionValue.panelOpened);
                  setState(() {
                    panelCollapsed = false;
                  });
                  if (panelClosed) {
                    logger.d('Screenshot Starting');
                    setState(() {
                      panelClosed = false;
                    });
                    if (colorChanged) {
                      screenshotController
                          .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                          .then((Uint8List? image) async {
                            setState(() {
                              _imageFile = File.fromRawPath(image!);
                              screenshotTaken = true;
                            });
                            logger.d('Screenshot Taken');
                          })
                          .catchError((onError) {
                            logger.d(onError.toString());
                          });
                    } else {
                      _settingsLocal.get<bool>('optimisedWallpapers', defaultValue: true) == true
                          ? screenshotController
                                .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                                .then((Uint8List? image) async {
                                  setState(() {
                                    _imageFile = File.fromRawPath(image!);
                                    screenshotTaken = true;
                                  });
                                  logger.d('Screenshot Taken');
                                })
                                .catchError((onError) {
                                  logger.d(onError.toString());
                                })
                          : logger.d("Wallpaper Optimisation is disabled!");
                    }
                  }
                },
                onPanelClosed: () {
                  _trackAction(AnalyticsActionValue.panelClosed);
                  setState(() {
                    panelCollapsed = true;
                  });
                  setState(() {
                    panelClosed = true;
                  });
                },
                backdropEnabled: true,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                boxShadow: const [],
                collapsed: CollapsedPanel(panelCollapsed: panelCollapsed, panelController: panelController),
                minHeight: MediaQuery.of(context).size.height / 20,
                parallaxEnabled: true,
                parallaxOffset: 0.00,
                color: Colors.transparent,
                maxHeight: MediaQuery.of(context).size.height * .43,
                controller: panelController,
                panel: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  height: MediaQuery.of(context).size.height * .43,
                  width: MediaQuery.of(context).size.width,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 750),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: panelCollapsed
                              ? Theme.of(context).primaryColor.withValues(alpha: 1)
                              : Theme.of(context).primaryColor.withValues(alpha: .5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: AnimatedOpacity(
                                  duration: Duration.zero,
                                  opacity: panelCollapsed ? 0.0 : 1.0,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_panelScrollInProgress) return;
                                      _trackAction(AnalyticsActionValue.panelCollapseTapped);
                                      panelController.close();
                                    },
                                    child: Icon(JamIcons.chevron_down, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                ),
                              ),
                            ),
                            ColorBar(colors: colors, fixedHeight: 64),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) => NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification is ScrollStartNotification) {
                                      setState(() => _panelScrollInProgress = true);
                                    } else if (notification is ScrollEndNotification) {
                                      Future.delayed(const Duration(milliseconds: 200), () {
                                        if (mounted) setState(() => _panelScrollInProgress = false);
                                      });
                                    }
                                    return false;
                                  },
                                  child: SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minHeight: constraints.maxHeight + 1),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                SizedBox(
                                                  width: MediaQuery.of(context).size.width * 0.36,
                                                  child: Padding(
                                                    padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                                    child: Wrap(
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      runSpacing: 4,
                                                      children: [
                                                        Text(
                                                          _prismWall.id.toUpperCase(),
                                                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                            color: Theme.of(context).colorScheme.secondary,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                                          child: Container(
                                                            height: 20,
                                                            color: Theme.of(context).colorScheme.secondary,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        FutureBuilder(
                                                          future: _futureView,
                                                          builder: (context, snapshot) {
                                                            switch (snapshot.connectionState) {
                                                              case ConnectionState.waiting:
                                                                return Text(
                                                                  "",
                                                                  style: Theme.of(context).textTheme.bodyLarge!
                                                                      .copyWith(
                                                                        color: Theme.of(context).colorScheme.secondary,
                                                                        fontSize: 16,
                                                                      ),
                                                                );
                                                              case ConnectionState.none:
                                                                return Text(
                                                                  "",
                                                                  style: Theme.of(context).textTheme.bodyLarge!
                                                                      .copyWith(
                                                                        color: Theme.of(context).colorScheme.secondary,
                                                                        fontSize: 16,
                                                                      ),
                                                                );
                                                              default:
                                                                if (snapshot.hasError) {
                                                                  return Text(
                                                                    "",
                                                                    style: Theme.of(context).textTheme.bodyLarge!
                                                                        .copyWith(
                                                                          color: Theme.of(
                                                                            context,
                                                                          ).colorScheme.secondary,
                                                                          fontSize: 16,
                                                                        ),
                                                                  );
                                                                } else {
                                                                  return Text(
                                                                    "${snapshot.data} views",
                                                                    style: Theme.of(context).textTheme.bodyLarge!
                                                                        .copyWith(
                                                                          color: Theme.of(
                                                                            context,
                                                                          ).colorScheme.secondary,
                                                                          fontSize: 16,
                                                                        ),
                                                                  );
                                                                }
                                                            }
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                SizedBox(
                                                  width: MediaQuery.of(context).size.width * 0.36,
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Icon(
                                                        JamIcons.arrow_circle_right,
                                                        size: 20,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.secondary.withValues(alpha: .7),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          _prismWall.core.category ?? '',
                                                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                            color: Theme.of(context).colorScheme.secondary,
                                                          ),
                                                          softWrap: true,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                SizedBox(
                                                  width: MediaQuery.of(context).size.width * 0.36,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        JamIcons.save,
                                                        size: 20,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.secondary.withValues(alpha: .7),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          _prismWall.core.sizeBytes?.toString() ?? '',
                                                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                            color: Theme.of(context).colorScheme.secondary,
                                                          ),
                                                          softWrap: true,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: <Widget>[
                                                SizedBox(
                                                  width: 160,
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Stack(
                                                      children: [
                                                        Align(
                                                          alignment: Alignment.topRight,
                                                          child: ActionChip(
                                                            onPressed: () {
                                                              context.router.push(
                                                                ProfileRoute(
                                                                  profileIdentifier: _prismWall.core.authorEmail ?? '',
                                                                ),
                                                              );
                                                            },
                                                            padding: const EdgeInsets.symmetric(
                                                              vertical: 5,
                                                              horizontal: 5,
                                                            ),
                                                            avatar: CircleAvatar(
                                                              backgroundImage: CachedNetworkImageProvider(
                                                                _prismWall.core.authorPhoto ?? '',
                                                              ),
                                                            ),
                                                            labelPadding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                                                            label: Text(
                                                              _prismWall.core.authorName ?? '',
                                                              style: Theme.of(context).textTheme.bodyMedium!
                                                                  .copyWith(
                                                                    color: Theme.of(context).colorScheme.secondary,
                                                                  )
                                                                  .copyWith(fontSize: 16),
                                                              overflow: TextOverflow.fade,
                                                            ),
                                                          ),
                                                        ),
                                                        if (app_state.verifiedUsers.contains(
                                                          _prismWall.core.authorEmail ?? '',
                                                        ))
                                                          Align(
                                                            alignment: Alignment.topRight,
                                                            child: SizedBox(
                                                              width: 20,
                                                              height: 20,
                                                              child: SvgPicture.string(
                                                                verifiedIcon.replaceAll(
                                                                  "E57697",
                                                                  Theme.of(context).colorScheme.error == Colors.black
                                                                      ? "E57697"
                                                                      : Theme.of(context).colorScheme.error
                                                                            .toString()
                                                                            .replaceAll("Color(0xff", "")
                                                                            .replaceAll(")", ""),
                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                        else
                                                          Container(),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Text(
                                                      _prismWall.core.resolution ?? '',
                                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                        color: Theme.of(context).colorScheme.secondary,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Icon(
                                                      JamIcons.set_square,
                                                      size: 20,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.secondary.withValues(alpha: .7),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                GestureDetector(
                                                  onTap: () async {
                                                    await createCopyrightLink(
                                                      false,
                                                      context,
                                                      id: _prismWall.id,
                                                      source: source,
                                                      url: _prismWall.fullUrl,
                                                      thumbUrl: _prismWall.thumbnailUrl,
                                                    );
                                                  },
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        "Report",
                                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                          decoration: TextDecoration.underline,
                                                          color: Theme.of(context).colorScheme.secondary,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Icon(
                                                        JamIcons.info,
                                                        size: 20,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.secondary.withValues(alpha: .7),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  DownloadButton(
                                    colorChanged: colorChanged,
                                    link: screenshotTaken ? _imageFile.path : _prismWall.fullUrl,
                                    isPremiumContent: app_state.isPremiumWall(
                                      app_state.premiumCollections,
                                      _prismWall.collections ?? const <String>[],
                                    ),
                                    contentId: _prismWall.id,
                                    sourceContext: 'wallpaper_screen.prism',
                                  ),
                                  if (!hideSetWallpaperUi)
                                    SetWallpaperButton(
                                      colorChanged: colorChanged,
                                      url: screenshotTaken ? _imageFile.path : _prismWall.fullUrl,
                                    ),
                                  FavouriteWallpaperButton(
                                    wall: PrismFavouriteWall(id: _prismWall.id, wallpaper: _prismWall),
                                    trash: false,
                                  ),
                                  ShareButton(
                                    id: _prismWall.id,
                                    source: source,
                                    url: _prismWall.fullUrl,
                                    thumbUrl: _prismWall.thumbnailUrl,
                                  ),
                                  EditButton(url: _prismWall.fullUrl),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                body: Stack(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: offsetAnimation,
                      builder: (buildContext, child) {
                        if (offsetAnimation.value < 0.0) {
                          logger.d('${offsetAnimation.value + 8.0}');
                        }
                        return GestureDetector(
                          onPanUpdate: (details) {
                            if (details.delta.dy < -10) {
                              panelController.open();
                            }
                          },
                          onLongPress: () {
                            _trackAction(AnalyticsActionValue.paletteResetLongPressed);
                            setState(() {
                              colorChanged = false;
                            });
                            HapticFeedback.vibrate();
                            shakeController.forward(from: 0.0);
                          },
                          onTap: () {
                            if (_panelScrollInProgress) return;
                            HapticFeedback.vibrate();
                            !paletteLoading ? updateAccent() : logger.d("");
                            shakeController.forward(from: 0.0);
                          },
                          child: CachedNetworkImage(
                            imageUrl: _prismWall.fullUrl,
                            imageBuilder: (context, imageProvider) => Screenshot(
                              controller: screenshotController,
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  vertical: offsetAnimation.value * 1.25,
                                  horizontal: offsetAnimation.value / 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(offsetAnimation.value),
                                  image: DecorationImage(
                                    colorFilter: colorChanged ? ColorFilter.mode(accent!, BlendMode.hue) : null,
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                              children: <Widget>[
                                const SizedBox.expand(child: Text("")),
                                Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                                    value: downloadProgress.progress,
                                  ),
                                ),
                              ],
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                JamIcons.close_circle_f,
                                color: paletteLoading
                                    ? Theme.of(context).colorScheme.secondary
                                    : accent!.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.backTapped);
                            Navigator.pop(context);
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.chevron_left),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.clockOverlayOpened);
                            final link = _prismWall.fullUrl;
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) {
                                  animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ClockOverlay(
                                      colorChanged: colorChanged,
                                      accent: accent,
                                      link: link,
                                      file: false,
                                    ),
                                  );
                                },
                                fullscreenDialog: true,
                                opaque: false,
                              ),
                            );
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.clock),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : source == WallpaperSource.pexels
          ? Scaffold(
              key: _scaffoldKey,
              backgroundColor: paletteLoading ? Theme.of(context).primaryColor : accent,
              body: SlidingUpPanel(
                onPanelOpened: () {
                  _trackAction(AnalyticsActionValue.panelOpened);
                  setState(() {
                    panelCollapsed = false;
                  });
                  if (panelClosed) {
                    logger.d('Screenshot Starting');
                    setState(() {
                      panelClosed = false;
                    });
                    if (colorChanged) {
                      screenshotController
                          .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                          .then((Uint8List? image) async {
                            setState(() {
                              _imageFile = File.fromRawPath(image!);
                              screenshotTaken = true;
                            });
                            logger.d('Screenshot Taken');
                          })
                          .catchError((onError) {
                            logger.d(onError.toString());
                          });
                    } else {
                      _settingsLocal.get<bool>('optimisedWallpapers', defaultValue: true) == true
                          ? screenshotController
                                .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                                .then((Uint8List? image) async {
                                  setState(() {
                                    _imageFile = File.fromRawPath(image!);
                                    screenshotTaken = true;
                                  });
                                  logger.d('Screenshot Taken');
                                })
                                .catchError((onError) {
                                  logger.d(onError.toString());
                                })
                          : logger.d("Wallpaper Optimisation is disabled!");
                    }
                  }
                },
                onPanelClosed: () {
                  _trackAction(AnalyticsActionValue.panelClosed);
                  setState(() {
                    panelCollapsed = true;
                  });
                  setState(() {
                    panelClosed = true;
                  });
                },
                backdropEnabled: true,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                boxShadow: const [],
                collapsed: CollapsedPanel(panelCollapsed: panelCollapsed, panelController: panelController),
                minHeight: MediaQuery.of(context).size.height / 20,
                parallaxEnabled: true,
                parallaxOffset: 0.00,
                color: Colors.transparent,
                maxHeight: MediaQuery.of(context).size.height * .43,
                controller: panelController,
                panel: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  height: MediaQuery.of(context).size.height * .43,
                  width: MediaQuery.of(context).size.width,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 750),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: panelCollapsed
                              ? Theme.of(context).primaryColor.withValues(alpha: 1)
                              : Theme.of(context).primaryColor.withValues(alpha: .5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: AnimatedOpacity(
                                  duration: Duration.zero,
                                  opacity: panelCollapsed ? 0.0 : 1.0,
                                  child: GestureDetector(
                                    onTap: () {
                                      _trackAction(AnalyticsActionValue.panelCollapseTapped);
                                      panelController.close();
                                    },
                                    child: Icon(JamIcons.chevron_down, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                ),
                              ),
                            ),
                            ColorBar(colors: colors, fixedHeight: 64),
                            Expanded(
                              flex: 8,
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(35, 0, 35, 15),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                        child: SizedBox(
                                          width: MediaQuery.of(context).size.width * .8,
                                          child: Text(
                                            _pexelsWall.core.fullUrl
                                                        .replaceAll("https://www.pexels.com/photo/", "")
                                                        .replaceAll("-", " ")
                                                        .replaceAll("/", "")
                                                        .length >
                                                    8
                                                ? _pexelsWall.core.fullUrl
                                                          .replaceAll("https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")[0]
                                                          .toUpperCase() +
                                                      _pexelsWall.core.fullUrl
                                                          .replaceAll("https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")
                                                          .substring(
                                                            1,
                                                            _pexelsWall.core.fullUrl
                                                                    .replaceAll("https://www.pexels.com/photo/", "")
                                                                    .replaceAll("-", " ")
                                                                    .replaceAll("/", "")
                                                                    .length -
                                                                7,
                                                          )
                                                : _pexelsWall.core.fullUrl
                                                          .replaceAll("https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")[0]
                                                          .toUpperCase() +
                                                      _pexelsWall.core.fullUrl
                                                          .replaceAll("https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")
                                                          .substring(1),
                                            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                              color: Theme.of(context).colorScheme.secondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: <Widget>[
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: [
                                                  Icon(
                                                    JamIcons.info,
                                                    size: 20,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.secondary.withValues(alpha: .7),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    _pexelsWall.id,
                                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  Icon(
                                                    JamIcons.set_square,
                                                    size: 20,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.secondary.withValues(alpha: .7),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    "${_pexelsWall.core.width}x${_pexelsWall.core.height}",
                                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: <Widget>[
                                              SizedBox(
                                                width: 160,
                                                child: Align(
                                                  alignment: Alignment.centerRight,
                                                  child: ActionChip(
                                                    onPressed: () {
                                                      openPrismLink(context, _pexelsWall.core.fullUrl);
                                                    },
                                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                                                    avatar: Icon(
                                                      JamIcons.camera,
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                    labelPadding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                                                    label: Text(
                                                      _pexelsWall.photographer.toString(),
                                                      style: Theme.of(context).textTheme.bodyMedium!
                                                          .copyWith(color: Theme.of(context).colorScheme.secondary)
                                                          .copyWith(fontSize: 16),
                                                      overflow: TextOverflow.fade,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    source.legacyProviderString,
                                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Icon(
                                                    JamIcons.database,
                                                    size: 20,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.secondary.withValues(alpha: .7),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  DownloadButton(
                                    colorChanged: colorChanged,
                                    link: screenshotTaken ? _imageFile.path : _pexelsWall.core.fullUrl,
                                  ),
                                  if (!hideSetWallpaperUi)
                                    SetWallpaperButton(
                                      colorChanged: colorChanged,
                                      url: screenshotTaken ? _imageFile.path : _pexelsWall.core.fullUrl,
                                    ),
                                  FavouriteWallpaperButton(
                                    wall: PexelsFavouriteWall(id: _pexelsWall.id, wallpaper: _pexelsWall),
                                    trash: false,
                                  ),
                                  ShareButton(
                                    id: _pexelsWall.id,
                                    source: source,
                                    url: _pexelsWall.core.fullUrl,
                                    thumbUrl: _pexelsWall.core.thumbnailUrl,
                                  ),
                                  EditButton(url: _pexelsWall.core.fullUrl),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                body: Stack(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: offsetAnimation,
                      builder: (buildContext, child) {
                        if (offsetAnimation.value < 0.0) {
                          logger.d('${offsetAnimation.value + 8.0}');
                        }
                        return GestureDetector(
                          onPanUpdate: (details) {
                            if (details.delta.dy < -10) {
                              panelController.open();
                            }
                          },
                          onLongPress: () {
                            _trackAction(AnalyticsActionValue.paletteResetLongPressed);
                            setState(() {
                              colorChanged = false;
                            });
                            HapticFeedback.vibrate();
                            shakeController.forward(from: 0.0);
                          },
                          onTap: () {
                            HapticFeedback.vibrate();
                            !paletteLoading ? updateAccent() : logger.d("");
                            shakeController.forward(from: 0.0);
                          },
                          child: CachedNetworkImage(
                            imageUrl: _pexelsWall.core.fullUrl,
                            imageBuilder: (context, imageProvider) => Screenshot(
                              controller: screenshotController,
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  vertical: offsetAnimation.value * 1.25,
                                  horizontal: offsetAnimation.value / 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(offsetAnimation.value),
                                  image: DecorationImage(
                                    colorFilter: colorChanged ? ColorFilter.mode(accent!, BlendMode.hue) : null,
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                              children: <Widget>[
                                const SizedBox.expand(child: Text("")),
                                Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                                    value: downloadProgress.progress,
                                  ),
                                ),
                              ],
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                JamIcons.close_circle_f,
                                color: paletteLoading
                                    ? Theme.of(context).colorScheme.secondary
                                    : accent!.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.backTapped);
                            Navigator.pop(context);
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.chevron_left),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.clockOverlayOpened);
                            final link = _pexelsWall.core.fullUrl;
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) {
                                  animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ClockOverlay(
                                      colorChanged: colorChanged,
                                      accent: accent,
                                      link: link,
                                      file: false,
                                    ),
                                  );
                                },
                                fullscreenDialog: true,
                                opaque: false,
                              ),
                            );
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.clock),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : source == WallpaperSource.unknown
          ? Scaffold(
              key: _scaffoldKey,
              backgroundColor: paletteLoading ? Theme.of(context).primaryColor : accent,
              body: SlidingUpPanel(
                onPanelOpened: () {
                  _trackAction(AnalyticsActionValue.panelOpened);
                  setState(() {
                    panelCollapsed = false;
                  });
                  if (panelClosed) {
                    logger.d('Screenshot Starting');
                    setState(() {
                      panelClosed = false;
                    });
                    if (colorChanged) {
                      screenshotController
                          .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                          .then((Uint8List? image) async {
                            setState(() {
                              _imageFile = File.fromRawPath(image!);
                              screenshotTaken = true;
                            });
                            logger.d('Screenshot Taken');
                          })
                          .catchError((onError) {
                            logger.d(onError.toString());
                          });
                    } else {
                      _settingsLocal.get<bool>('optimisedWallpapers', defaultValue: true) == true
                          ? screenshotController
                                .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                                .then((Uint8List? image) async {
                                  setState(() {
                                    _imageFile = File.fromRawPath(image!);
                                    screenshotTaken = true;
                                  });
                                  logger.d('Screenshot Taken');
                                })
                                .catchError((onError) {
                                  logger.d(onError.toString());
                                })
                          : logger.d("Wallpaper Optimisation is disabled!");
                    }
                  }
                },
                onPanelClosed: () {
                  _trackAction(AnalyticsActionValue.panelClosed);
                  setState(() {
                    panelCollapsed = true;
                  });
                  setState(() {
                    panelClosed = true;
                  });
                },
                backdropEnabled: true,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                boxShadow: const [],
                collapsed: CollapsedPanel(panelCollapsed: panelCollapsed, panelController: panelController),
                minHeight: MediaQuery.of(context).size.height / 20,
                parallaxEnabled: true,
                parallaxOffset: 0.00,
                color: Colors.transparent,
                maxHeight: MediaQuery.of(context).size.height * .43,
                controller: panelController,
                panel: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  height: MediaQuery.of(context).size.height * .43,
                  width: MediaQuery.of(context).size.width,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 750),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: panelCollapsed
                              ? Theme.of(context).primaryColor.withValues(alpha: 1)
                              : Theme.of(context).primaryColor.withValues(alpha: .5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: AnimatedOpacity(
                                  duration: Duration.zero,
                                  opacity: panelCollapsed ? 0.0 : 1.0,
                                  child: GestureDetector(
                                    onTap: () {
                                      _trackAction(AnalyticsActionValue.panelCollapseTapped);
                                      panelController.close();
                                    },
                                    child: Icon(JamIcons.chevron_down, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                ),
                              ),
                            ),
                            ColorBar(colors: colors, fixedHeight: 64),
                            Expanded(
                              flex: 8,
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(35, 0, 35, 15),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                        child: SizedBox(
                                          width: MediaQuery.of(context).size.width * .8,
                                          child: Text(
                                            pdata.wallsC[index].core.fullUrl
                                                        .replaceAll("https://www.pexels.com/photo/", "")
                                                        .replaceAll("-", " ")
                                                        .replaceAll("/", "")
                                                        .length >
                                                    8
                                                ? pdata.wallsC[index].core.fullUrl
                                                          .replaceAll("https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")[0]
                                                          .toUpperCase() +
                                                      pdata.wallsC[index].core.fullUrl
                                                          .replaceAll("https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")
                                                          .substring(
                                                            1,
                                                            pdata.wallsC[index].core.fullUrl
                                                                    .replaceAll("https://www.pexels.com/photo/", "")
                                                                    .replaceAll("-", " ")
                                                                    .replaceAll("/", "")
                                                                    .length -
                                                                7,
                                                          )
                                                : pdata.wallsC[index].core.fullUrl
                                                          .replaceAll("https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")[0]
                                                          .toUpperCase() +
                                                      pdata.wallsC[index].core.fullUrl
                                                          .replaceAll("https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")
                                                          .substring(1),
                                            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                              color: Theme.of(context).colorScheme.secondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: <Widget>[
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: [
                                                  Icon(
                                                    JamIcons.info,
                                                    size: 20,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.secondary.withValues(alpha: .7),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    pdata.wallsC[index].id,
                                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  Icon(
                                                    JamIcons.set_square,
                                                    size: 20,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.secondary.withValues(alpha: .7),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    "${pdata.wallsC[index].core.width}x${pdata.wallsC[index].core.height}",
                                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: <Widget>[
                                              SizedBox(
                                                width: 160,
                                                child: Align(
                                                  alignment: Alignment.centerRight,
                                                  child: ActionChip(
                                                    onPressed: () {
                                                      openPrismLink(context, pdata.wallsC[index].core.fullUrl);
                                                    },
                                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                                                    avatar: Icon(
                                                      JamIcons.camera,
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                    labelPadding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                                                    label: Text(
                                                      pdata.wallsC[index].photographer.toString(),
                                                      style: Theme.of(context).textTheme.bodyMedium!
                                                          .copyWith(color: Theme.of(context).colorScheme.secondary)
                                                          .copyWith(fontSize: 16),
                                                      overflow: TextOverflow.fade,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    "Pexels",
                                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Icon(
                                                    JamIcons.database,
                                                    size: 20,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.secondary.withValues(alpha: .7),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  DownloadButton(
                                    colorChanged: colorChanged,
                                    link: screenshotTaken ? _imageFile.path : pdata.wallsC[index].core.fullUrl,
                                  ),
                                  if (!hideSetWallpaperUi)
                                    SetWallpaperButton(
                                      colorChanged: colorChanged,
                                      url: screenshotTaken ? _imageFile.path : pdata.wallsC[index].core.fullUrl,
                                    ),
                                  FavouriteWallpaperButton(
                                    wall: PexelsFavouriteWall(
                                      id: pdata.wallsC[index].id,
                                      wallpaper: pdata.wallsC[index],
                                    ),
                                    trash: false,
                                  ),
                                  ShareButton(
                                    id: pdata.wallsC[index].id,
                                    source: WallpaperSource.pexels,
                                    url: pdata.wallsC[index].core.fullUrl,
                                    thumbUrl: pdata.wallsC[index].core.thumbnailUrl,
                                  ),
                                  EditButton(url: pdata.wallsC[index].core.fullUrl),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                body: Stack(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: offsetAnimation,
                      builder: (buildContext, child) {
                        if (offsetAnimation.value < 0.0) {
                          logger.d('${offsetAnimation.value + 8.0}');
                        }
                        return GestureDetector(
                          onPanUpdate: (details) {
                            if (details.delta.dy < -10) {
                              panelController.open();
                            }
                          },
                          onLongPress: () {
                            _trackAction(AnalyticsActionValue.paletteResetLongPressed);
                            setState(() {
                              colorChanged = false;
                            });
                            HapticFeedback.vibrate();
                            shakeController.forward(from: 0.0);
                          },
                          onTap: () {
                            HapticFeedback.vibrate();
                            !paletteLoading ? updateAccent() : logger.d("");
                            shakeController.forward(from: 0.0);
                          },
                          child: CachedNetworkImage(
                            imageUrl: pdata.wallsC[index].core.thumbnailUrl,
                            imageBuilder: (context, imageProvider) => Screenshot(
                              controller: screenshotController,
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  vertical: offsetAnimation.value * 1.25,
                                  horizontal: offsetAnimation.value / 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(offsetAnimation.value),
                                  image: DecorationImage(
                                    colorFilter: colorChanged ? ColorFilter.mode(accent!, BlendMode.hue) : null,
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                              children: <Widget>[
                                const SizedBox.expand(child: Text("")),
                                Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                                    value: downloadProgress.progress,
                                  ),
                                ),
                              ],
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                JamIcons.close_circle_f,
                                color: paletteLoading
                                    ? Theme.of(context).colorScheme.secondary
                                    : accent!.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.backTapped);
                            Navigator.pop(context);
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.chevron_left),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.clockOverlayOpened);
                            final link = pdata.wallsC[index].core.fullUrl;
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) {
                                  animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ClockOverlay(
                                      colorChanged: colorChanged,
                                      accent: accent,
                                      link: link,
                                      file: false,
                                    ),
                                  );
                                },
                                fullscreenDialog: true,
                                opaque: false,
                              ),
                            );
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.clock),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Scaffold(
              key: _scaffoldKey,
              backgroundColor: paletteLoading ? Theme.of(context).primaryColor : accent,
              body: SlidingUpPanel(
                onPanelOpened: () {
                  _trackAction(AnalyticsActionValue.panelOpened);
                  setState(() {
                    panelCollapsed = false;
                  });
                  if (panelClosed) {
                    logger.d('Screenshot Starting');
                    setState(() {
                      panelClosed = false;
                    });
                    if (colorChanged) {
                      screenshotController
                          .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                          .then((Uint8List? image) async {
                            setState(() {
                              _imageFile = File.fromRawPath(image!);
                              screenshotTaken = true;
                            });
                            logger.d('Screenshot Taken');
                          })
                          .catchError((onError) {
                            logger.d(onError.toString());
                          });
                    } else {
                      _settingsLocal.get<bool>('optimisedWallpapers', defaultValue: true) == true
                          ? screenshotController
                                .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
                                .then((Uint8List? image) async {
                                  setState(() {
                                    _imageFile = File.fromRawPath(image!);
                                    screenshotTaken = true;
                                  });
                                  logger.d('Screenshot Taken');
                                })
                                .catchError((onError) {
                                  logger.d(onError.toString());
                                })
                          : logger.d("Wallpaper Optimisation is disabled!");
                    }
                  }
                },
                onPanelClosed: () {
                  _trackAction(AnalyticsActionValue.panelClosed);
                  setState(() {
                    panelCollapsed = true;
                  });
                  setState(() {
                    panelClosed = true;
                  });
                },
                backdropEnabled: true,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                boxShadow: const [],
                collapsed: CollapsedPanel(panelCollapsed: panelCollapsed, panelController: panelController),
                minHeight: MediaQuery.of(context).size.height / 20,
                parallaxEnabled: true,
                parallaxOffset: 0.00,
                color: Colors.transparent,
                maxHeight: MediaQuery.of(context).size.height * .43,
                controller: panelController,
                panel: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  height: MediaQuery.of(context).size.height * .43,
                  width: MediaQuery.of(context).size.width,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 750),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: panelCollapsed
                              ? Theme.of(context).primaryColor.withValues(alpha: 1)
                              : Theme.of(context).primaryColor.withValues(alpha: .5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: AnimatedOpacity(
                                  duration: Duration.zero,
                                  opacity: panelCollapsed ? 0.0 : 1.0,
                                  child: GestureDetector(
                                    onTap: () {
                                      _trackAction(AnalyticsActionValue.panelCollapseTapped);
                                      panelController.close();
                                    },
                                    child: Icon(JamIcons.chevron_down, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                ),
                              ),
                            ),
                            ColorBar(colors: colors, fixedHeight: 64),
                            Expanded(
                              flex: 8,
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(35, 0, 35, 15),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                            child: Text(
                                              wdata.wallsS[index].id.toUpperCase(),
                                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                color: Theme.of(context).colorScheme.secondary,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                JamIcons.eye,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                wdata.wallsS[index].views.toString(),
                                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Icon(
                                                JamIcons.heart_f,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                wdata.wallsS[index].core.favourites.toString(),
                                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Icon(
                                                JamIcons.save,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                "${double.parse((double.parse(wdata.wallsS[index].core.sizeBytes?.toString() ?? '0') / 1000000).toString()).toStringAsFixed(2)} MB",
                                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: <Widget>[
                                          Padding(
                                            padding: EdgeInsets.zero,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    wdata.wallsS[index].core.category.toString()[0].toUpperCase() +
                                                        wdata.wallsS[index].core.category.toString().substring(1),
                                                    overflow: TextOverflow.ellipsis,
                                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                      color: Theme.of(context).colorScheme.secondary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Icon(
                                                  JamIcons.unordered_list,
                                                  size: 20,
                                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  wdata.wallsS[index].core.resolution.toString(),
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                    color: Theme.of(context).colorScheme.secondary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                JamIcons.set_square,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  source.legacyProviderString,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                    color: Theme.of(context).colorScheme.secondary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                JamIcons.search,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  DownloadButton(
                                    colorChanged: colorChanged,
                                    link: screenshotTaken ? _imageFile.path : wdata.wallsS[index].core.fullUrl,
                                  ),
                                  if (!hideSetWallpaperUi)
                                    SetWallpaperButton(
                                      colorChanged: colorChanged,
                                      url: screenshotTaken ? _imageFile.path : wdata.wallsS[index].core.fullUrl,
                                    ),
                                  FavouriteWallpaperButton(
                                    wall: WallhavenFavouriteWall(
                                      id: wdata.wallsS[index].id,
                                      wallpaper: wdata.wallsS[index],
                                    ),
                                    trash: false,
                                  ),
                                  ShareButton(
                                    id: wdata.wallsS[index].id,
                                    source: WallpaperSource.wallhaven,
                                    url: wdata.wallsS[index].core.fullUrl,
                                    thumbUrl: wdata.wallsS[index].core.thumbnailUrl,
                                  ),
                                  EditButton(url: wdata.wallsS[index].core.fullUrl),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                body: Stack(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: offsetAnimation,
                      builder: (buildContext, child) {
                        if (offsetAnimation.value < 0.0) {
                          logger.d('${offsetAnimation.value + 8.0}');
                        }
                        return GestureDetector(
                          onPanUpdate: (details) {
                            if (details.delta.dy < -10) {
                              panelController.open();
                            }
                          },
                          onLongPress: () {
                            _trackAction(AnalyticsActionValue.paletteResetLongPressed);
                            setState(() {
                              colorChanged = false;
                            });
                            HapticFeedback.vibrate();
                            shakeController.forward(from: 0.0);
                          },
                          onTap: () {
                            HapticFeedback.vibrate();
                            !paletteLoading ? updateAccent() : logger.d("");
                            shakeController.forward(from: 0.0);
                          },
                          child: CachedNetworkImage(
                            imageUrl: wdata.wallsS[index].core.thumbnailUrl,
                            imageBuilder: (context, imageProvider) => Screenshot(
                              controller: screenshotController,
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  vertical: offsetAnimation.value * 1.25,
                                  horizontal: offsetAnimation.value / 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(offsetAnimation.value),
                                  image: DecorationImage(
                                    colorFilter: colorChanged ? ColorFilter.mode(accent!, BlendMode.hue) : null,
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                              children: <Widget>[
                                const SizedBox.expand(child: Text("")),
                                Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                                    value: downloadProgress.progress,
                                  ),
                                ),
                              ],
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                JamIcons.close_circle_f,
                                color: paletteLoading
                                    ? Theme.of(context).colorScheme.secondary
                                    : accent!.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.backTapped);
                            Navigator.pop(context);
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.chevron_left),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.clockOverlayOpened);
                            final link = wdata.wallsS[index].core.fullUrl;
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) {
                                  animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ClockOverlay(
                                      colorChanged: colorChanged,
                                      accent: accent,
                                      link: link,
                                      file: false,
                                    ),
                                  );
                                },
                                fullscreenDialog: true,
                                opaque: false,
                              ),
                            );
                          },
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          icon: const Icon(JamIcons.clock),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
