import 'dart:io';
import 'dart:ui';
import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as WData;
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/ui/widgets/home/wallpapers/clockOverlay.dart';
import 'package:Prism/ui/widgets/home/core/colorBar.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/editButton.dart';
import 'package:Prism/ui/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/ui/widgets/menuButton/shareButton.dart';
import 'package:Prism/ui/widgets/popup/copyrightPopUp.dart';
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/global/svgAssets.dart';

class ShareWallpaperViewScreen extends StatefulWidget {
  final List arguments;
  const ShareWallpaperViewScreen({this.arguments});

  @override
  _ShareWallpaperViewScreenState createState() =>
      _ShareWallpaperViewScreenState();
}

class _ShareWallpaperViewScreenState extends State<ShareWallpaperViewScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String id;
  String provider;
  String url;
  String thumb;
  bool isLoading = true;
  PaletteGenerator paletteGenerator;
  List<Color> colors;
  Color accent;
  bool colorChanged = false;
  File _imageFile;
  bool screenshotTaken = false;
  ScreenshotController screenshotController = ScreenshotController();
  AnimationController shakeController;
  Future<WallPaper> futureW;
  Future<WallPaperP> futureP;
  Future<Map> futureM;
  PanelController panelController = PanelController();
  ImageProvider<Object> image;
  bool panelClosed = true;
  bool panelCollapsed = true;

  Future<void> _updatePaletteGenerator() async {
    setState(() {
      isLoading = true;
    });
    try {
      image = CachedNetworkImageProvider(thumb);
    } catch (e) {
      e.toString();
    }
    await Future.delayed(const Duration(milliseconds: 500)).then((value) async {
      paletteGenerator = await PaletteGenerator.fromImageProvider(image,
          maximumColorCount: 20, timeout: const Duration(seconds: 120));
    });
    setState(() {
      isLoading = false;
    });
    colors = paletteGenerator.colors.toList();
    debugPrint(colors.toString());
    if (paletteGenerator.colors.length > 5) {
      colors = colors.sublist(0, 5);
    }
    setState(() {
      accent = colors[0];
    });
    if (accent.computeLuminance() > 0.5) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
          .copyWith(statusBarIconBrightness: Brightness.dark));
    } else {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
          .copyWith(statusBarIconBrightness: Brightness.light));
    }
  }

  void updateAccent() {
    if (colors.contains(accent)) {
      final index = colors.indexOf(accent);
      setState(() {
        accent = colors[(index + 1) % 5];
      });
      setState(() {
        colorChanged = true;
      });
      if (accent.computeLuminance() > 0.5) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
            .copyWith(statusBarIconBrightness: Brightness.dark));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
            .copyWith(statusBarIconBrightness: Brightness.light));
      }
    }
  }

  @override
  void initState() {
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    id = widget.arguments[0].toString();
    provider = widget.arguments[1].toString();
    url = widget.arguments[2].toString();
    thumb = widget.arguments[3].toString();
    isLoading = true;
    if (provider == "WallHaven") {
      futureW = WData.getWallbyID(id);
    } else if (provider == "Pexels") {
      futureP = PData.getWallbyIDP(id);
    } else if (provider == "Prism") {
      futureM = Data.getDataByID(id);
    }
    _updatePaletteGenerator();
    super.initState();
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation = Tween(begin: 0.0, end: 48.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    return WillPopScope(
      onWillPop: onWillPop,
      child: provider == "WallHaven"
          ? Scaffold(
              resizeToAvoidBottomPadding: false,
              key: _scaffoldKey,
              backgroundColor:
                  isLoading ? Theme.of(context).primaryColor : accent,
              body: SlidingUpPanel(
                onPanelOpened: () {
                  setState(() {
                    panelCollapsed = false;
                  });
                  if (panelClosed) {
                    debugPrint('Screenshot Starting');
                    if (colorChanged) {
                      screenshotController
                          .capture(
                        pixelRatio: 3,
                        delay: const Duration(milliseconds: 10),
                      )
                          .then((File image) async {
                        setState(() {
                          _imageFile = image;
                          screenshotTaken = true;
                          panelClosed = false;
                        });
                        debugPrint('Screenshot Taken');
                      }).catchError((onError) {
                        debugPrint(onError.toString());
                      });
                    } else {
                      (main.prefs.get('optimisedWallpapers') ?? true) == true
                          ? screenshotController
                              .capture(
                              pixelRatio: 3,
                              delay: const Duration(milliseconds: 10),
                            )
                              .then((File image) async {
                              setState(() {
                                _imageFile = image;
                                screenshotTaken = true;
                                panelClosed = false;
                              });
                              debugPrint('Screenshot Taken');
                            }).catchError((onError) {
                              debugPrint(onError.toString());
                            })
                          : debugPrint("Wallpaper Optimisation is disabled!");
                    }
                  }
                },
                onPanelClosed: () {
                  setState(() {
                    panelCollapsed = true;
                  });
                  setState(() {
                    panelClosed = true;
                  });
                },
                backdropEnabled: true,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: const [],
                collapsed: CollapsedPanel(
                  panelCollapsed: panelCollapsed,
                  panelController: panelController,
                ),
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
                              ? Theme.of(context).primaryColor.withOpacity(1)
                              : Theme.of(context).primaryColor.withOpacity(.5),
                        ),
                        child: FutureBuilder<WallPaper>(
                            future: futureW,
                            builder:
                                (context, AsyncSnapshot<WallPaper> snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  snapshot.connectionState ==
                                      ConnectionState.none) {
                                debugPrint(
                                    "snapshot none, waiting in share route");
                                return Center(child: Loader());
                              } else {
                                debugPrint("done");
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Center(
                                        child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: AnimatedOpacity(
                                        duration: const Duration(),
                                        opacity: panelCollapsed ? 0.0 : 1.0,
                                        child: GestureDetector(
                                          onTap: () {
                                            panelController.close();
                                          },
                                          child: Icon(
                                            JamIcons.chevron_down,
                                            color:
                                                Theme.of(context).accentColor,
                                          ),
                                        ),
                                      ),
                                    )),
                                    ColorBar(colors: colors),
                                    Expanded(
                                      flex: 8,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            35, 0, 35, 10),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: <Widget>[
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          0, 5, 0, 10),
                                                  child: Text(
                                                    id.toString().toUpperCase(),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyText1
                                                        .copyWith(
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor),
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      JamIcons.eye,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .accentColor
                                                          .withOpacity(.7),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      "${WData.wall == null ? 0 : WData.wall.views.toString()}",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText2
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      JamIcons.heart_f,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .accentColor
                                                          .withOpacity(.7),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      "${WData.wall == null ? 0 : WData.wall.favourites.toString()}",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText2
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      JamIcons.save,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .accentColor
                                                          .withOpacity(.7),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      "${WData.wall == null ? 0 : (double.parse((double.parse(WData.wall.file_size.toString()) / 1000000).toString()).toStringAsFixed(2))} MB",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText2
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: <Widget>[
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          0, 0, 0, 0),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        WData.wall == null
                                                            ? "General"
                                                            : (WData.wall
                                                                    .category
                                                                    .toString()[
                                                                        0]
                                                                    .toUpperCase() +
                                                                WData.wall
                                                                    .category
                                                                    .toString()
                                                                    .substring(
                                                                        1)),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText2
                                                            .copyWith(
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Icon(
                                                        JamIcons.unordered_list,
                                                        size: 20,
                                                        color: Theme.of(context)
                                                            .accentColor
                                                            .withOpacity(.7),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Text(
                                                      "${WData.wall == null ? 0x0 : WData.wall.resolution.toString()}",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText2
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Icon(
                                                      JamIcons.set_square,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .accentColor
                                                          .withOpacity(.7),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Text(
                                                      provider.toString(),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText2
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Icon(
                                                      JamIcons.database,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .accentColor
                                                          .withOpacity(.7),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: <Widget>[
                                          DownloadButton(
                                              colorChanged: colorChanged,
                                              link: screenshotTaken
                                                  ? _imageFile.path
                                                  : WData.wall == null
                                                      ? ""
                                                      : WData.wall.path
                                                          .toString()),
                                          SetWallpaperButton(
                                            colorChanged: colorChanged,
                                            url: screenshotTaken
                                                ? _imageFile.path
                                                : WData.wall == null
                                                    ? ""
                                                    : WData.wall.path
                                                        .toString(),
                                          ),
                                          FavouriteWallpaperButton(
                                            id: WData.wall == null
                                                ? ""
                                                : WData.wall.id.toString(),
                                            provider: "WallHaven",
                                            wallhaven:
                                                WData.wall ?? WallPaper(),
                                            trash: false,
                                          ),
                                          ShareButton(
                                              id: WData.wall == null
                                                  ? ""
                                                  : WData.wall.id.toString(),
                                              provider: provider,
                                              url: WData.wall == null
                                                  ? ""
                                                  : WData.wall.path.toString(),
                                              thumbUrl: WData.wall == null
                                                  ? ""
                                                  : WData
                                                      .wall.thumbs["original"]
                                                      .toString()),
                                          EditButton(
                                            url: WData.wall == null
                                                ? ""
                                                : WData.wall.path.toString(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                            }),
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
                            debugPrint('${offsetAnimation.value + 8.0}');
                          }
                          return GestureDetector(
                            onPanUpdate: (details) {
                              if (details.delta.dy < -10) {
                                // HapticFeedback.vibrate();
                                panelController.open();
                              }
                            },
                            onLongPress: () {
                              setState(() {
                                colorChanged = false;
                              });
                              HapticFeedback.vibrate();
                              shakeController.forward(from: 0.0);
                            },
                            onTap: () {
                              HapticFeedback.vibrate();
                              !isLoading ? updateAccent() : debugPrint("");
                              shakeController.forward(from: 0.0);
                            },
                            child: CachedNetworkImage(
                              imageUrl: url,
                              imageBuilder: (context, imageProvider) =>
                                  Screenshot(
                                controller: screenshotController,
                                child: Container(
                                  margin: EdgeInsets.symmetric(
                                      vertical: offsetAnimation.value * 1.25,
                                      horizontal: offsetAnimation.value / 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        offsetAnimation.value),
                                    image: DecorationImage(
                                      colorFilter: colorChanged
                                          ? ColorFilter.mode(
                                              accent, BlendMode.hue)
                                          : null,
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              progressIndicatorBuilder:
                                  (context, url, downloadProgress) => Stack(
                                children: <Widget>[
                                  const SizedBox.expand(child: Text("")),
                                  Center(
                                    child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(
                                          config.Colors().mainAccentColor(1),
                                        ),
                                        value: downloadProgress.progress),
                                  ),
                                ],
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(
                                  JamIcons.close_circle_f,
                                  color: isLoading
                                      ? Theme.of(context).accentColor
                                      : accent.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                ),
                              ),
                            ),
                          );
                        }),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            8.0, globals.notchSize + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            navStack.removeLast();
                            debugPrint(navStack.toString());
                            Navigator.pop(context);
                          },
                          color: isLoading
                              ? Theme.of(context).accentColor
                              : accent.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                          icon: const Icon(
                            JamIcons.chevron_left,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            8.0, globals.notchSize + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            final link = url;
                            Navigator.push(
                                context,
                                PageRouteBuilder(
                                    transitionDuration:
                                        const Duration(milliseconds: 300),
                                    pageBuilder: (context, animation,
                                        secondaryAnimation) {
                                      animation = Tween(begin: 0.0, end: 1.0)
                                          .animate(animation);
                                      return FadeTransition(
                                          opacity: animation,
                                          child: ClockOverlay(
                                            colorChanged: colorChanged,
                                            accent: accent,
                                            link: link,
                                            file: false,
                                          ));
                                    },
                                    fullscreenDialog: true,
                                    opaque: false));
                          },
                          color: isLoading
                              ? Theme.of(context).accentColor
                              : accent.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                          icon: const Icon(
                            JamIcons.clock,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          : provider == "Prism"
              ? Scaffold(
                  resizeToAvoidBottomPadding: false,
                  key: _scaffoldKey,
                  backgroundColor:
                      isLoading ? Theme.of(context).primaryColor : accent,
                  body: SlidingUpPanel(
                    onPanelOpened: () {
                      setState(() {
                        panelCollapsed = false;
                      });
                      if (panelClosed) {
                        debugPrint('Screenshot Starting');
                        if (colorChanged) {
                          screenshotController
                              .capture(
                            pixelRatio: 3,
                            delay: const Duration(milliseconds: 10),
                          )
                              .then((File image) async {
                            setState(() {
                              _imageFile = image;
                              screenshotTaken = true;
                              panelClosed = false;
                            });
                            debugPrint('Screenshot Taken');
                          }).catchError((onError) {
                            debugPrint(onError.toString());
                          });
                        } else {
                          (main.prefs.get('optimisedWallpapers') ?? true) ==
                                  true
                              ? screenshotController
                                  .capture(
                                  pixelRatio: 3,
                                  delay: const Duration(milliseconds: 10),
                                )
                                  .then((File image) async {
                                  setState(() {
                                    _imageFile = image;
                                    screenshotTaken = true;
                                    panelClosed = false;
                                  });
                                  debugPrint('Screenshot Taken');
                                }).catchError((onError) {
                                  debugPrint(onError.toString());
                                })
                              : debugPrint(
                                  "Wallpaper Optimisation is disabled!");
                        }
                      }
                    },
                    onPanelClosed: () {
                      setState(() {
                        panelCollapsed = true;
                      });
                      setState(() {
                        panelClosed = true;
                      });
                    },
                    backdropEnabled: true,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: const [],
                    collapsed: CollapsedPanel(
                      panelCollapsed: panelCollapsed,
                      panelController: panelController,
                    ),
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
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(1)
                                  : Theme.of(context)
                                      .primaryColor
                                      .withOpacity(.5),
                            ),
                            child: FutureBuilder<Map>(
                                future: futureM,
                                builder:
                                    (context, AsyncSnapshot<Map> snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      snapshot.connectionState ==
                                          ConnectionState.none) {
                                    debugPrint(
                                        "snapshot none, waiting in share route");
                                    return Center(child: Loader());
                                  } else {
                                    debugPrint("done");
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Center(
                                            child: Padding(
                                          padding: const EdgeInsets.all(10.0),
                                          child: AnimatedOpacity(
                                            duration: const Duration(),
                                            opacity: panelCollapsed ? 0.0 : 1.0,
                                            child: GestureDetector(
                                              onTap: () {
                                                panelController.close();
                                              },
                                              child: Icon(
                                                JamIcons.chevron_down,
                                                color: Theme.of(context)
                                                    .accentColor,
                                              ),
                                            ),
                                          ),
                                        )),
                                        ColorBar(colors: colors),
                                        Expanded(
                                          flex: 8,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                35, 0, 35, 10),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: <Widget>[
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Padding(
                                                      padding: const EdgeInsets
                                                              .fromLTRB(
                                                          0, 5, 0, 10),
                                                      child: Text(
                                                        id
                                                            .toString()
                                                            .toUpperCase(),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText1
                                                            .copyWith(
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          JamIcons
                                                              .arrow_circle_right,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Text(
                                                          "${Data.wall == null ? 0 : Data.wall["desc"].toString()}",
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          JamIcons.save,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Text(
                                                          "${Data.wall == null ? 0 : Data.wall["size"].toString()}",
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: <Widget>[
                                                    SizedBox(
                                                      width: 160,
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: Stack(
                                                          children: [
                                                            Align(
                                                              alignment:
                                                                  Alignment
                                                                      .topRight,
                                                              child: ActionChip(
                                                                onPressed:
                                                                    Data.wall ==
                                                                            null
                                                                        ? () {}
                                                                        : () {
                                                                            Navigator.pushNamed(context, photographerProfileRoute, arguments: [
                                                                              Data.wall["by"],
                                                                              Data.wall["email"],
                                                                              Data.wall["userPhoto"],
                                                                              false,
                                                                              Data.wall["twitter"] != null && Data.wall["twitter"] != "" ? Data.wall["twitter"].toString().split("https://www.twitter.com/")[1] : "",
                                                                              Data.wall["instagram"] != null && Data.wall["instagram"] != "" ? Data.wall["instagram"].toString().split("https://www.instagram.com/")[1] : "",
                                                                            ]);
                                                                          },
                                                                padding: const EdgeInsets
                                                                        .symmetric(
                                                                    vertical: 5,
                                                                    horizontal:
                                                                        5),
                                                                avatar:
                                                                    CircleAvatar(
                                                                  backgroundImage:
                                                                      CachedNetworkImageProvider(Data
                                                                          .wall[
                                                                              "userPhoto"]
                                                                          .toString()),
                                                                ),
                                                                labelPadding:
                                                                    const EdgeInsets
                                                                            .fromLTRB(
                                                                        7,
                                                                        3,
                                                                        7,
                                                                        3),
                                                                label: Text(
                                                                    Data.wall ==
                                                                            null
                                                                        ? "Photographer"
                                                                        : Data
                                                                            .wall[
                                                                                "by"]
                                                                            .toString(),
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyText2
                                                                        .copyWith(
                                                                            color: Theme.of(context)
                                                                                .accentColor)
                                                                        .copyWith(
                                                                            fontSize:
                                                                                16),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .fade),
                                                              ),
                                                            ),
                                                            globals.verifiedUsers
                                                                    .contains(Data
                                                                        .wall[
                                                                            "email"]
                                                                        .toString())
                                                                ? Align(
                                                                    alignment:
                                                                        Alignment
                                                                            .topRight,
                                                                    child:
                                                                        Container(
                                                                      width: 20,
                                                                      height:
                                                                          20,
                                                                      child: SvgPicture.string(verifiedIcon.replaceAll(
                                                                          "E57697",
                                                                          config.Colors().mainAccentColor(1) == Colors.black
                                                                              ? "E57697"
                                                                              : main.prefs.get("mainAccentColor").toRadixString(16).toString().substring(2))),
                                                                    ),
                                                                  )
                                                                : Container(),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          "${Data.wall == null ? 0x0 : Data.wall["resolution"].toString()}",
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Icon(
                                                          JamIcons.set_square,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 5),
                                                    GestureDetector(
                                                      onTap: () {
                                                        showModal(
                                                            context: context,
                                                            configuration:
                                                                const FadeScaleTransitionConfiguration(),
                                                            builder: (BuildContext
                                                                    context) =>
                                                                CopyrightPopUp(
                                                                  setup: false,
                                                                  shortlink:
                                                                      "Wallpaper ID - ${Data.wall["id"]}",
                                                                ));
                                                      },
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            "Copyright",
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyText2
                                                                .copyWith(
                                                                    decoration:
                                                                        TextDecoration
                                                                            .underline,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          Icon(
                                                            JamIcons.info,
                                                            size: 20,
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor
                                                                .withOpacity(
                                                                    .7),
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
                                        Expanded(
                                          flex: 5,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: <Widget>[
                                              DownloadButton(
                                                  colorChanged: colorChanged,
                                                  link: screenshotTaken
                                                      ? _imageFile.path
                                                      : Data.wall == null
                                                          ? ""
                                                          : Data.wall[
                                                                  "wallpaper_url"]
                                                              .toString()),
                                              SetWallpaperButton(
                                                colorChanged: colorChanged,
                                                url: screenshotTaken
                                                    ? _imageFile.path
                                                    : Data.wall == null
                                                        ? ""
                                                        : Data.wall[
                                                                "wallpaper_url"]
                                                            .toString(),
                                              ),
                                              FavouriteWallpaperButton(
                                                id: Data.wall == null
                                                    ? ""
                                                    : Data.wall["id"]
                                                        .toString(),
                                                provider: "Prism",
                                                prism: Data.wall ?? {},
                                                trash: false,
                                              ),
                                              ShareButton(
                                                  id: Data.wall["id"]
                                                      .toString(),
                                                  provider: provider,
                                                  url: Data
                                                      .wall["wallpaper_url"]
                                                      .toString(),
                                                  thumbUrl: Data
                                                      .wall["wallpaper_thumb"]
                                                      .toString()),
                                              EditButton(
                                                url: Data.wall["wallpaper_url"]
                                                    .toString(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                }),
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
                                debugPrint('${offsetAnimation.value + 8.0}');
                              }
                              return GestureDetector(
                                onPanUpdate: (details) {
                                  if (details.delta.dy < -10) {
                                    // HapticFeedback.vibrate();
                                    panelController.open();
                                  }
                                },
                                onLongPress: () {
                                  setState(() {
                                    colorChanged = false;
                                  });
                                  HapticFeedback.vibrate();
                                  shakeController.forward(from: 0.0);
                                },
                                onTap: () {
                                  HapticFeedback.vibrate();
                                  !isLoading ? updateAccent() : debugPrint("");
                                  shakeController.forward(from: 0.0);
                                },
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  imageBuilder: (context, imageProvider) =>
                                      Screenshot(
                                    controller: screenshotController,
                                    child: Container(
                                      margin: EdgeInsets.symmetric(
                                          vertical:
                                              offsetAnimation.value * 1.25,
                                          horizontal:
                                              offsetAnimation.value / 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                            offsetAnimation.value),
                                        image: DecorationImage(
                                          colorFilter: colorChanged
                                              ? ColorFilter.mode(
                                                  accent, BlendMode.hue)
                                              : null,
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  progressIndicatorBuilder:
                                      (context, url, downloadProgress) => Stack(
                                    children: <Widget>[
                                      const SizedBox.expand(child: Text("")),
                                      Center(
                                        child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation(
                                              config.Colors()
                                                  .mainAccentColor(1),
                                            ),
                                            value: downloadProgress.progress),
                                      ),
                                    ],
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      JamIcons.close_circle_f,
                                      color: isLoading
                                          ? Theme.of(context).accentColor
                                          : accent.computeLuminance() > 0.5
                                              ? Colors.black
                                              : Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }),
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                8.0, globals.notchSize + 8, 8, 8),
                            child: IconButton(
                              onPressed: () {
                                navStack.removeLast();
                                debugPrint(navStack.toString());
                                Navigator.pop(context);
                              },
                              color: isLoading
                                  ? Theme.of(context).accentColor
                                  : accent.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                              icon: const Icon(
                                JamIcons.chevron_left,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                8.0, globals.notchSize + 8, 8, 8),
                            child: IconButton(
                              onPressed: () {
                                final link = url;
                                Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                        transitionDuration:
                                            const Duration(milliseconds: 300),
                                        pageBuilder: (context, animation,
                                            secondaryAnimation) {
                                          animation =
                                              Tween(begin: 0.0, end: 1.0)
                                                  .animate(animation);
                                          return FadeTransition(
                                              opacity: animation,
                                              child: ClockOverlay(
                                                colorChanged: colorChanged,
                                                accent: accent,
                                                link: link,
                                                file: false,
                                              ));
                                        },
                                        fullscreenDialog: true,
                                        opaque: false));
                              },
                              color: isLoading
                                  ? Theme.of(context).accentColor
                                  : accent.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                              icon: const Icon(
                                JamIcons.clock,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              : provider == "Pexels"
                  ? Scaffold(
                      resizeToAvoidBottomPadding: false,
                      key: _scaffoldKey,
                      backgroundColor:
                          isLoading ? Theme.of(context).primaryColor : accent,
                      body: SlidingUpPanel(
                        onPanelOpened: () {
                          setState(() {
                            panelCollapsed = false;
                          });
                          if (panelClosed) {
                            debugPrint('Screenshot Starting');
                            if (colorChanged) {
                              screenshotController
                                  .capture(
                                pixelRatio: 3,
                                delay: const Duration(milliseconds: 10),
                              )
                                  .then((File image) async {
                                setState(() {
                                  _imageFile = image;
                                  screenshotTaken = true;
                                  panelClosed = false;
                                });
                                debugPrint('Screenshot Taken');
                              }).catchError((onError) {
                                debugPrint(onError.toString());
                              });
                            } else {
                              (main.prefs.get('optimisedWallpapers') ?? true) ==
                                      true
                                  ? screenshotController
                                      .capture(
                                      pixelRatio: 3,
                                      delay: const Duration(milliseconds: 10),
                                    )
                                      .then((File image) async {
                                      setState(() {
                                        _imageFile = image;
                                        screenshotTaken = true;
                                        panelClosed = false;
                                      });
                                      debugPrint('Screenshot Taken');
                                    }).catchError((onError) {
                                      debugPrint(onError.toString());
                                    })
                                  : debugPrint(
                                      "Wallpaper Optimisation is disabled!");
                            }
                          }
                        },
                        onPanelClosed: () {
                          setState(() {
                            panelCollapsed = true;
                          });
                          setState(() {
                            panelClosed = true;
                          });
                        },
                        backdropEnabled: true,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        boxShadow: const [],
                        collapsed: CollapsedPanel(
                          panelCollapsed: panelCollapsed,
                          panelController: panelController,
                        ),
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
                                filter: ImageFilter.blur(
                                    sigmaX: 12.0, sigmaY: 12.0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 750),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    color: panelCollapsed
                                        ? Theme.of(context)
                                            .primaryColor
                                            .withOpacity(1)
                                        : Theme.of(context)
                                            .primaryColor
                                            .withOpacity(.5),
                                  ),
                                  child: FutureBuilder<WallPaperP>(
                                      future: futureP,
                                      builder: (context,
                                          AsyncSnapshot<WallPaperP> snapshot) {
                                        if (snapshot.connectionState ==
                                                ConnectionState.waiting ||
                                            snapshot.connectionState ==
                                                ConnectionState.none) {
                                          debugPrint(
                                              "snapshot none, waiting in share route");
                                          return Center(child: Loader());
                                        } else {
                                          debugPrint("done");
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Center(
                                                  child: Padding(
                                                padding:
                                                    const EdgeInsets.all(10.0),
                                                child: AnimatedOpacity(
                                                  duration: const Duration(),
                                                  opacity: panelCollapsed
                                                      ? 0.0
                                                      : 1.0,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      panelController.close();
                                                    },
                                                    child: Icon(
                                                      JamIcons.chevron_down,
                                                      color: Theme.of(context)
                                                          .accentColor,
                                                    ),
                                                  ),
                                                ),
                                              )),
                                              ColorBar(colors: colors),
                                              Expanded(
                                                flex: 8,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          35, 0, 35, 15),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                    .fromLTRB(
                                                                0, 5, 0, 10),
                                                        child: Container(
                                                          width: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              .8,
                                                          child: Text(
                                                            PData.wall == null
                                                                ? "Wallpaper"
                                                                : (PData.wall.url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length > 8
                                                                    ? PData.wall.url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "")[0].toUpperCase() +
                                                                        PData.wall.url
                                                                            .toString()
                                                                            .replaceAll(
                                                                                "https://www.pexels.com/photo/", "")
                                                                            .replaceAll(
                                                                                "-", " ")
                                                                            .replaceAll(
                                                                                "/", "")
                                                                            .substring(
                                                                                1,
                                                                                PData.wall.url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length -
                                                                                    7)
                                                                    : PData.wall
                                                                            .url
                                                                            .toString()
                                                                            .replaceAll(
                                                                                "https://www.pexels.com/photo/", "")
                                                                            .replaceAll(
                                                                                "-", " ")
                                                                            .replaceAll("/", "")[
                                                                                0]
                                                                            .toUpperCase() +
                                                                        PData
                                                                            .wall
                                                                            .url
                                                                            .toString()
                                                                            .replaceAll("https://www.pexels.com/photo/", "")
                                                                            .replaceAll("-", " ")
                                                                            .replaceAll("/", "")
                                                                            .substring(1)),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyText1
                                                                .copyWith(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            maxLines: 1,
                                                          ),
                                                        ),
                                                      ),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: <Widget>[
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: <Widget>[
                                                              Row(
                                                                children: [
                                                                  const Icon(
                                                                    JamIcons
                                                                        .camera,
                                                                    size: 20,
                                                                    color: Colors
                                                                        .white70,
                                                                  ),
                                                                  const SizedBox(
                                                                      width:
                                                                          10),
                                                                  Container(
                                                                    width: MediaQuery.of(context)
                                                                            .size
                                                                            .width *
                                                                        .4,
                                                                    child: Text(
                                                                      PData.wall ==
                                                                              null
                                                                          ? "Photographer"
                                                                          : PData
                                                                              .wall
                                                                              .photographer
                                                                              .toString(),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .left,
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .bodyText2
                                                                          .copyWith(
                                                                              color: Theme.of(context).accentColor),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                  height: 5),
                                                              Row(
                                                                children: [
                                                                  const Icon(
                                                                    JamIcons
                                                                        .set_square,
                                                                    size: 20,
                                                                    color: Colors
                                                                        .white70,
                                                                  ),
                                                                  const SizedBox(
                                                                      width:
                                                                          10),
                                                                  Text(
                                                                    "${PData.wall == null ? 0 : PData.wall.width.toString()}x${PData.wall == null ? 0 : PData.wall.height.toString()}",
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyText2
                                                                        .copyWith(
                                                                            color:
                                                                                Theme.of(context).accentColor),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            children: <Widget>[
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    id.toString(),
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyText2
                                                                        .copyWith(
                                                                            color:
                                                                                Theme.of(context).accentColor),
                                                                  ),
                                                                  const SizedBox(
                                                                      width:
                                                                          10),
                                                                  const Icon(
                                                                    JamIcons
                                                                        .info,
                                                                    size: 20,
                                                                    color: Colors
                                                                        .white70,
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                  height: 5),
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    provider
                                                                        .toString(),
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyText2
                                                                        .copyWith(
                                                                            color:
                                                                                Theme.of(context).accentColor),
                                                                  ),
                                                                  const SizedBox(
                                                                      width:
                                                                          10),
                                                                  const Icon(
                                                                    JamIcons
                                                                        .database,
                                                                    size: 20,
                                                                    color: Colors
                                                                        .white70,
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
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: <Widget>[
                                                    DownloadButton(
                                                      colorChanged:
                                                          colorChanged,
                                                      link: screenshotTaken
                                                          ? _imageFile.path
                                                          : url.toString(),
                                                    ),
                                                    SetWallpaperButton(
                                                      colorChanged:
                                                          colorChanged,
                                                      url: screenshotTaken
                                                          ? _imageFile.path
                                                          : url.toString(),
                                                    ),
                                                    FavouriteWallpaperButton(
                                                      id: PData.wall == null
                                                          ? ""
                                                          : PData.wall.id
                                                              .toString(),
                                                      provider: "Pexels",
                                                      pexels: PData.wall ??
                                                          WallPaperP(),
                                                      trash: false,
                                                    ),
                                                    PData.wall != null
                                                        ? ShareButton(
                                                            id: PData.wall.id ??
                                                                "",
                                                            provider: provider,
                                                            url: url.toString(),
                                                            thumbUrl:
                                                                url.toString(),
                                                          )
                                                        : Container(),
                                                    EditButton(
                                                      url: url.toString(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                      }),
                                ),
                              ),
                            )),
                        body: Stack(
                          children: <Widget>[
                            AnimatedBuilder(
                                animation: offsetAnimation,
                                builder: (buildContext, child) {
                                  if (offsetAnimation.value < 0.0) {
                                    debugPrint(
                                        '${offsetAnimation.value + 8.0}');
                                  }
                                  return GestureDetector(
                                    onPanUpdate: (details) {
                                      if (details.delta.dy < -10) {
                                        // HapticFeedback.vibrate();
                                        panelController.open();
                                      }
                                    },
                                    onLongPress: () {
                                      setState(() {
                                        colorChanged = false;
                                      });
                                      HapticFeedback.vibrate();
                                      shakeController.forward(from: 0.0);
                                    },
                                    onTap: () {
                                      HapticFeedback.vibrate();
                                      !isLoading
                                          ? updateAccent()
                                          : debugPrint("");
                                      shakeController.forward(from: 0.0);
                                    },
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      imageBuilder: (context, imageProvider) =>
                                          Screenshot(
                                        controller: screenshotController,
                                        child: Container(
                                          margin: EdgeInsets.symmetric(
                                              vertical:
                                                  offsetAnimation.value * 1.25,
                                              horizontal:
                                                  offsetAnimation.value / 2),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                                offsetAnimation.value),
                                            image: DecorationImage(
                                              colorFilter: colorChanged
                                                  ? ColorFilter.mode(
                                                      accent, BlendMode.hue)
                                                  : null,
                                              image: imageProvider,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                      progressIndicatorBuilder:
                                          (context, url, downloadProgress) =>
                                              Stack(
                                        children: <Widget>[
                                          const SizedBox.expand(
                                              child: Text("")),
                                          Center(
                                            child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                  config.Colors()
                                                      .mainAccentColor(1),
                                                ),
                                                value:
                                                    downloadProgress.progress),
                                          ),
                                        ],
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Center(
                                        child: Icon(
                                          JamIcons.close_circle_f,
                                          color: isLoading
                                              ? Theme.of(context).accentColor
                                              : accent.computeLuminance() > 0.5
                                                  ? Colors.black
                                                  : Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                            Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                    8.0, globals.notchSize + 8, 8, 8),
                                child: IconButton(
                                  onPressed: () {
                                    navStack.removeLast();
                                    debugPrint(navStack.toString());
                                    Navigator.pop(context);
                                  },
                                  color: isLoading
                                      ? Theme.of(context).accentColor
                                      : colors[0].computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                  icon: const Icon(
                                    JamIcons.chevron_left,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                    8.0, globals.notchSize + 8, 8, 8),
                                child: IconButton(
                                  onPressed: () {
                                    final link = url;
                                    Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                            transitionDuration: const Duration(
                                                milliseconds: 300),
                                            pageBuilder: (context, animation,
                                                secondaryAnimation) {
                                              animation =
                                                  Tween(begin: 0.0, end: 1.0)
                                                      .animate(animation);
                                              return FadeTransition(
                                                  opacity: animation,
                                                  child: ClockOverlay(
                                                    colorChanged: colorChanged,
                                                    accent: accent,
                                                    link: link,
                                                    file: false,
                                                  ));
                                            },
                                            fullscreenDialog: true,
                                            opaque: false));
                                  },
                                  color: isLoading
                                      ? Theme.of(context).accentColor
                                      : colors[0].computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                  icon: const Icon(
                                    JamIcons.clock,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  : Container(),
    );
  }
}
