import 'dart:io';
import 'dart:ui';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/ui/widgets/home/wallpapers/clockOverlay.dart';
import 'package:Prism/ui/widgets/home/core/colorBar.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/editButton.dart';
import 'package:Prism/ui/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/ui/widgets/menuButton/shareButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/global/globals.dart' as globals;

class ProfileWallViewScreen extends StatefulWidget {
  final List arguments;
  const ProfileWallViewScreen({this.arguments});

  @override
  _ProfileWallViewScreenState createState() => _ProfileWallViewScreenState();
}

class _ProfileWallViewScreenState extends State<ProfileWallViewScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int index;
  String thumb;
  bool isLoading = true;
  PaletteGenerator paletteGenerator;
  List<Color> colors;
  Color accent;
  bool colorChanged = false;
  String downloadLinkBackwards;
  File _imageFile;
  bool screenshotTaken = false;
  ScreenshotController screenshotController = ScreenshotController();
  PanelController panelController = PanelController();
  AnimationController shakeController;
  bool panelClosed = true;
  bool panelCollapsed = true;

  Future<void> _updatePaletteGenerator() async {
    setState(() {
      isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 500)).then((value) async {
      paletteGenerator = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(thumb),
        maximumColorCount: 20,
      );
    });
    setState(() {
      isLoading = false;
    });
    colors = paletteGenerator.colors.toList();
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
    index = widget.arguments[0] as int;
    thumb = widget.arguments[1].toString();
    isLoading = true;
    _updatePaletteGenerator();
    super.initState();
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
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
        child: Scaffold(
          resizeToAvoidBottomPadding: false,
          key: _scaffoldKey,
          backgroundColor: isLoading ? Theme.of(context).primaryColor : accent,
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
                  main.prefs.get('optimisedWallpapers') as bool ?? true
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Center(
                            child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: AnimatedOpacity(
                            duration: const Duration(),
                            opacity: panelCollapsed ? 0.0 : 1.0,
                            child: GestureDetector(
                            onTap: (){
                              panelController.close();
                            },
                                                      child: Icon(
                              JamIcons.chevron_down,
                              color: Theme.of(context).accentColor,
                            ),),
                          ),
                        )),
                        ColorBar(colors: colors),
                        Expanded(
                          flex: 8,
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
                                      padding: const EdgeInsets.fromLTRB(
                                          0, 5, 0, 10),
                                      child: Text(
                                        Provider.of<ProfileWallProvider>(
                                                context,
                                                listen: false)
                                            .profileWalls[index]["id"]
                                            .toString()
                                            .toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText1
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .accentColor),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          JamIcons.camera,
                                          size: 20,
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(.7),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          Provider.of<ProfileWallProvider>(
                                                  context,
                                                  listen: false)
                                              .profileWalls[index]["by"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(
                                          JamIcons.arrow_circle_right,
                                          size: 20,
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(.7),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          Provider.of<ProfileWallProvider>(
                                                  context,
                                                  listen: false)
                                              .profileWalls[index]["desc"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .copyWith(
                                                  color: Theme.of(context)
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
                                          Provider.of<ProfileWallProvider>(
                                                  context,
                                                  listen: false)
                                              .profileWalls[index]["size"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        Text(
                                          Provider.of<ProfileWallProvider>(
                                                  context,
                                                  listen: false)
                                              .profileWalls[index]["resolution"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .copyWith(
                                                  color: Theme.of(context)
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
                                          Provider.of<ProfileWallProvider>(
                                                  context,
                                                  listen: false)
                                              .profileWalls[index]
                                                  ["wallpaper_provider"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .copyWith(
                                                  color: Theme.of(context)
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
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              DownloadButton(
                                colorChanged: colorChanged,
                                link: screenshotTaken
                                    ? _imageFile.path
                                    : Provider.of<ProfileWallProvider>(context,
                                            listen: false)
                                        .profileWalls[index]["wallpaper_url"]
                                        .toString(),
                              ),
                              SetWallpaperButton(
                                colorChanged: colorChanged,
                                url: screenshotTaken
                                    ? _imageFile.path
                                    : Provider.of<ProfileWallProvider>(context,
                                            listen: false)
                                        .profileWalls[index]["wallpaper_url"]
                                        .toString(),
                              ),
                              FavouriteWallpaperButton(
                                id: Provider.of<ProfileWallProvider>(context,
                                        listen: false)
                                    .profileWalls[index]["id"]
                                    .toString(),
                                provider: Provider.of<ProfileWallProvider>(
                                        context,
                                        listen: false)
                                    .profileWalls[index]["wallpaper_provider"]
                                    .toString(),
                                trash: false,
                              ),
                              ShareButton(
                                  id: Provider.of<ProfileWallProvider>(context,
                                          listen: false)
                                      .profileWalls[index]["id"]
                                      .toString(),
                                  provider: Provider.of<ProfileWallProvider>(
                                          context,
                                          listen: false)
                                      .profileWalls[index]["wallpaper_provider"]
                                      .toString(),
                                  url: Provider.of<ProfileWallProvider>(context,
                                          listen: false)
                                      .profileWalls[index]["wallpaper_url"]
                                      .toString(),
                                  thumbUrl: Provider.of<ProfileWallProvider>(
                                          context,
                                          listen: false)
                                      .profileWalls[index]["wallpaper_thumb"]
                                      .toString()),
                              EditButton(
                                url: Provider.of<ProfileWallProvider>(context,
                                        listen: false)
                                    .profileWalls[index]["wallpaper_url"]
                                    .toString(),
                              ),
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
                        debugPrint('${offsetAnimation.value + 8.0}');
                      }
                      return GestureDetector(
                        onPanUpdate: (details) {
                          if (details.delta.dy < -10) {
                            panelController.open();
                            // HapticFeedback.vibrate();
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
                          imageUrl: Provider.of<ProfileWallProvider>(context,
                                  listen: false)
                              .profileWalls[index]["wallpaper_url"]
                              .toString(),
                          imageBuilder: (context, imageProvider) => Screenshot(
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
                                      ? ColorFilter.mode(accent, BlendMode.hue)
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
                    padding:
                        EdgeInsets.fromLTRB(8.0, globals.notchSize + 8, 8, 8),
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
                    padding:
                        EdgeInsets.fromLTRB(8.0, globals.notchSize + 8, 8, 8),
                    child: IconButton(
                      onPressed: () {
                        final link = Provider.of<ProfileWallProvider>(context,
                                listen: false)
                            .profileWalls[index]["wallpaper_url"];
                        Navigator.push(
                            context,
                            PageRouteBuilder(
                                transitionDuration:
                                    const Duration(milliseconds: 300),
                                pageBuilder:
                                    (context, animation, secondaryAnimation) {
                                  animation = Tween(begin: 0.0, end: 1.0)
                                      .animate(animation);
                                  return FadeTransition(
                                      opacity: animation,
                                      child: ClockOverlay(
                                        colorChanged: colorChanged,
                                        accent: accent,
                                        link: link.toString(),
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
        ));
  }
}
