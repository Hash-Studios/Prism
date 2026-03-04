import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/core/widgets/home/core/colorBar.dart';
import 'package:Prism/core/widgets/menuButton/editButton.dart';
import 'package:Prism/core/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/core/widgets/menuButton/shareButton.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart' as wdata;
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/palette/views/widgets/clock_overlay.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

@RoutePage()
class SearchWallpaperScreen extends StatefulWidget {
  const SearchWallpaperScreen({
    super.key,
    required this.source,
    required this.query,
    required this.index,
    required this.link,
  });

  final WallpaperSource source;
  final String query;
  final int index;
  final String link;

  @override
  _SearchWallpaperScreenState createState() => _SearchWallpaperScreenState();
}

class _SearchWallpaperScreenState extends State<SearchWallpaperScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  late WallpaperSource source;
  late String query;
  late int index;
  late String link;
  late AnimationController shakeController;
  bool isLoading = true;
  late PaletteGenerator paletteGenerator;
  List<Color?>? colors;
  Color? accent;
  bool colorChanged = false;
  late File _imageFile;
  bool screenshotTaken = false;
  ScreenshotController screenshotController = ScreenshotController();
  PanelController panelController = PanelController();
  bool panelClosed = true;
  bool panelCollapsed = true;

  String get _sourceContext => '${source.wireValue}_search_wallpaper_screen';

  void _trackAction(AnalyticsActionValue action) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.searchWallpaperScreen,
          action: action,
          sourceContext: _sourceContext,
          itemType: ItemTypeValue.wallpaper,
          index: index,
        ),
      ),
    );
  }

  Future<void> _updatePaletteGenerator() async {
    _contentLoadTracker.start();
    setState(() {
      isLoading = true;
    });
    try {
      await Future.delayed(const Duration(milliseconds: 500)).then((value) async {
        paletteGenerator = await PaletteGenerator.fromImageProvider(
          CachedNetworkImageProvider(link),
          maximumColorCount: 20,
        );
      });
    } catch (_) {
      _contentLoadTracker.failure(
        reason: AnalyticsReasonValue.error,
        onFailure: ({required int loadTimeMs, AnalyticsReasonValue? reason, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.searchWallpaperScreen,
              result: EventResultValue.failure,
              loadTimeMs: loadTimeMs,
              sourceContext: _sourceContext,
              reason: reason,
            ),
          );
        },
      );
      rethrow;
    }
    setState(() {
      isLoading = false;
    });
    colors = paletteGenerator.colors.toList();
    if (paletteGenerator.colors.length > 5) {
      colors = colors!.sublist(0, 5);
    }
    setState(() {
      accent = colors![0];
    });
    _contentLoadTracker.success(
      itemCount: colors?.length,
      onSuccess: ({required int loadTimeMs, int? itemCount}) async {
        await analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.searchWallpaperScreen,
            result: EventResultValue.success,
            loadTimeMs: loadTimeMs,
            sourceContext: _sourceContext,
            itemCount: itemCount,
          ),
        );
      },
    );
    if (accent!.computeLuminance() > 0.5) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle.dark.copyWith(statusBarIconBrightness: Brightness.dark),
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle.dark.copyWith(statusBarIconBrightness: Brightness.light),
      );
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
      if (accent!.computeLuminance() > 0.5) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle.dark.copyWith(statusBarIconBrightness: Brightness.dark),
        );
      } else {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle.dark.copyWith(statusBarIconBrightness: Brightness.light),
        );
      }
    }
    _trackAction(AnalyticsActionValue.paletteCycleTapped);
  }

  @override
  void initState() {
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    super.initState();
    source = widget.source;
    query = widget.query;
    index = widget.index;
    link = widget.link;
    isLoading = true;
    _contentLoadTracker.start();
    _updatePaletteGenerator();
  }

  @override
  void dispose() {
    super.dispose();
    shakeController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation =
        Tween(begin: 0.0, end: 48.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    return source == WallpaperSource.wallhaven
        ? Scaffold(
            key: _scaffoldKey,
            backgroundColor: isLoading ? Theme.of(context).primaryColor : accent,
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
                            panelClosed = false;
                          });
                          logger.d('Screenshot Taken');
                        })
                        .catchError((onError) {
                          logger.d(onError.toString());
                        });
                  } else {
                    main.prefs.get('optimisedWallpapers') as bool? ?? true
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
                          ColorBar(colors: colors),
                          Expanded(
                            flex: 8,
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
                                          wdata.wallsS[index].id.toString().toUpperCase(),
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
                                            "${double.parse((double.parse(wdata.wallsS[index].sizeBytes.toString()) / 1000000).toString()).toStringAsFixed(2)} MB",
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
                                          children: [
                                            Text(
                                              wdata.wallsS[index].core.category.toString()[0].toUpperCase() +
                                                  wdata.wallsS[index].core.category.toString().substring(1),
                                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                color: Theme.of(context).colorScheme.secondary,
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
                                        children: [
                                          Text(
                                            wdata.wallsS[index].core.resolution.toString(),
                                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                              color: Theme.of(context).colorScheme.secondary,
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
                                        children: [
                                          Text(
                                            query.toString()[0].toUpperCase() + query.toString().substring(1),
                                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                              color: Theme.of(context).colorScheme.secondary,
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
                          !isLoading ? updateAccent() : logger.d("");
                          shakeController.forward(from: 0.0);
                        },
                        child: CachedNetworkImage(
                          imageUrl: wdata.wallsS[index].core.fullUrl,
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
                              color: isLoading
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
                        color: isLoading
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
                        color: isLoading
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
            backgroundColor: isLoading ? Theme.of(context).primaryColor : accent,
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
                            panelClosed = false;
                          });
                          logger.d('Screenshot Taken');
                        })
                        .catchError((onError) {
                          logger.d(onError.toString());
                        });
                  } else {
                    main.prefs.get('optimisedWallpapers') as bool? ?? true
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
                          ColorBar(colors: colors),
                          Expanded(
                            flex: 8,
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
                                        pdata.wallsPS[index].core.fullUrl
                                                    .replaceAll("https://www.pexels.com/photo/", "")
                                                    .replaceAll("-", " ")
                                                    .replaceAll("/", "")
                                                    .length >
                                                8
                                            ? pdata.wallsPS[index].core.fullUrl
                                                      .replaceAll("https://www.pexels.com/photo/", "")
                                                      .replaceAll("-", " ")
                                                      .replaceAll("/", "")[0]
                                                      .toUpperCase() +
                                                  pdata.wallsPS[index].core.fullUrl
                                                      .replaceAll("https://www.pexels.com/photo/", "")
                                                      .replaceAll("-", " ")
                                                      .replaceAll("/", "")
                                                      .substring(
                                                        1,
                                                        pdata.wallsPS[index].core.fullUrl
                                                                .replaceAll("https://www.pexels.com/photo/", "")
                                                                .replaceAll("-", " ")
                                                                .replaceAll("/", "")
                                                                .length -
                                                            7,
                                                      )
                                            : pdata.wallsPS[index].core.fullUrl
                                                      .replaceAll("https://www.pexels.com/photo/", "")
                                                      .replaceAll("-", " ")
                                                      .replaceAll("/", "")[0]
                                                      .toUpperCase() +
                                                  pdata.wallsPS[index].core.fullUrl
                                                      .replaceAll("https://www.pexels.com/photo/", "")
                                                      .replaceAll("-", " ")
                                                      .replaceAll("/", "")
                                                      .substring(1),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
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
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                pdata.wallsPS[index].id.toString(),
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
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                "${pdata.wallsPS[index].core.width}x${pdata.wallsPS[index].core.height}",
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
                                                  openPrismLink(context, pdata.wallsPS[index].core.fullUrl);
                                                },
                                                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                                                avatar: Icon(
                                                  JamIcons.camera,
                                                  color: Theme.of(context).colorScheme.secondary,
                                                ),
                                                labelPadding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                                                label: Text(
                                                  pdata.wallsPS[index].photographer.toString(),
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
                                                query.toString(),
                                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                  color: Theme.of(context).colorScheme.secondary,
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
                                ],
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
                                  link: screenshotTaken ? _imageFile.path : pdata.wallsPS[index].core.fullUrl,
                                ),
                                if (!hideSetWallpaperUi)
                                  SetWallpaperButton(
                                    colorChanged: colorChanged,
                                    url: screenshotTaken ? _imageFile.path : pdata.wallsPS[index].core.fullUrl,
                                  ),
                                FavouriteWallpaperButton(
                                  wall: PexelsFavouriteWall(
                                    id: pdata.wallsPS[index].id,
                                    wallpaper: pdata.wallsPS[index],
                                  ),
                                  trash: false,
                                ),
                                ShareButton(
                                  id: pdata.wallsPS[index].id,
                                  source: source,
                                  url: pdata.wallsPS[index].core.fullUrl,
                                  thumbUrl: pdata.wallsPS[index].core.thumbnailUrl,
                                ),
                                EditButton(url: pdata.wallsPS[index].core.fullUrl),
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
                          !isLoading ? updateAccent() : logger.d("");
                          shakeController.forward(from: 0.0);
                        },
                        child: CachedNetworkImage(
                          imageUrl: pdata.wallsPS[index].core.fullUrl,
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
                              color: isLoading
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
                        color: isLoading
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
                          final link = pdata.wallsPS[index].core.fullUrl;
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
                                    link: link.toString(),
                                    file: false,
                                  ),
                                );
                              },
                              fullscreenDialog: true,
                              opaque: false,
                            ),
                          );
                        },
                        color: isLoading
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
          );
  }
}
