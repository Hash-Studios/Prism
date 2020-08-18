import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/clockOverlay.dart';
import 'package:Prism/ui/widgets/home/colorBar.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
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
import 'dart:io';

class ProfileWallViewScreen extends StatefulWidget {
  final List arguments;
  ProfileWallViewScreen({this.arguments});

  @override
  _ProfileWallViewScreenState createState() => _ProfileWallViewScreenState();
}

class _ProfileWallViewScreenState extends State<ProfileWallViewScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
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

  Future<void> _updatePaletteGenerator() async {
    setState(() {
      isLoading = true;
    });
    paletteGenerator = await PaletteGenerator.fromImageProvider(
      new CachedNetworkImageProvider(thumb),
      maximumColorCount: 20,
    );
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
  }

  void updateAccent() {
    if (colors.contains(accent)) {
      var index = colors.indexOf(accent);
      setState(() {
        accent = colors[(index + 1) % 5];
      });
      setState(() {
        colorChanged = true;
      });
    }
  }

  @override
  void initState() {
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    index = widget.arguments[0];
    thumb = widget.arguments[1];
    isLoading = true;
    _updatePaletteGenerator();
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([]);
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  @override
  Widget build(BuildContext context) {
    // try {
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
              if (panelClosed) {
                print('Screenshot Starting');
                screenshotController
                    .capture(
                  pixelRatio: 3,
                  delay: Duration(milliseconds: 10),
                )
                    .then((File image) async {
                  setState(() {
                    _imageFile = image;
                    screenshotTaken = true;
                    panelClosed = false;
                  });
                  print('Screenshot Taken');
                }).catchError((onError) {
                  print(onError);
                });
              }
            },
            onPanelClosed: () {
              setState(() {
                panelClosed = true;
              });
            },
            backdropEnabled: true,
            backdropTapClosesPanel: true,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [],
            collapsed: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  color: Color(0xFF2F2F2F)),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height / 20,
                child: Center(
                    child: Icon(
                  JamIcons.chevron_up,
                  color: Colors.white,
                )),
              ),
            ),
            minHeight: MediaQuery.of(context).size.height / 20,
            parallaxEnabled: true,
            parallaxOffset: 0.54,
            color: Color(0xFF2F2F2F),
            maxHeight: MediaQuery.of(context).size.height * .46,
            controller: panelController,
            panel: Container(
              height: MediaQuery.of(context).size.height * .42,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Color(0xFF2F2F2F),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Icon(
                      JamIcons.chevron_down,
                      color: Colors.white,
                    ),
                  )),
                  ColorBar(colors: colors),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                child: Text(
                                  Provider.of<ProfileWallProvider>(context,
                                          listen: false)
                                      .profileWalls[index]["id"]
                                      .toString()
                                      .toUpperCase(),
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    JamIcons.camera,
                                    size: 20,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "${Provider.of<ProfileWallProvider>(context, listen: false).profileWalls[index]["by"].toString()}",
                                    style:
                                        Theme.of(context).textTheme.bodyText2,
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    JamIcons.arrow_circle_right,
                                    size: 20,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "${Provider.of<ProfileWallProvider>(context, listen: false).profileWalls[index]["desc"].toString()}",
                                    style:
                                        Theme.of(context).textTheme.bodyText2,
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    JamIcons.save,
                                    size: 20,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "${Provider.of<ProfileWallProvider>(context, listen: false).profileWalls[index]["size"].toString()}",
                                    style:
                                        Theme.of(context).textTheme.bodyText2,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Row(
                                children: [
                                  Text(
                                    "${Provider.of<ProfileWallProvider>(context, listen: false).profileWalls[index]["resolution"].toString()}",
                                    style:
                                        Theme.of(context).textTheme.bodyText2,
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    JamIcons.set_square,
                                    size: 20,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Text(
                                    Provider.of<ProfileWallProvider>(context,
                                            listen: false)
                                        .profileWalls[index]
                                            ["wallpaper_provider"]
                                        .toString(),
                                    style:
                                        Theme.of(context).textTheme.bodyText2,
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    JamIcons.database,
                                    size: 20,
                                    color: Colors.white70,
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
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        DownloadButton(
                          colorChanged: colorChanged,
                          link: screenshotTaken
                              ? _imageFile.path
                              : Provider.of<ProfileWallProvider>(context,
                                      listen: false)
                                  .profileWalls[index]["wallpaper_url"],
                        ),
                        SetWallpaperButton(
                          colorChanged: colorChanged,
                          url: screenshotTaken
                              ? _imageFile.path
                              : Provider.of<ProfileWallProvider>(context,
                                      listen: false)
                                  .profileWalls[index]["wallpaper_url"],
                        ),
                        FavouriteWallpaperButton(
                          id: Provider.of<ProfileWallProvider>(context,
                                  listen: false)
                              .profileWalls[index]["id"]
                              .toString(),
                          provider: Provider.of<ProfileWallProvider>(context,
                                  listen: false)
                              .profileWalls[index]["wallpaper_provider"]
                              .toString(),
                          trash: false,
                        ),
                        ShareButton(
                            id: Provider.of<ProfileWallProvider>(context,
                                    listen: false)
                                .profileWalls[index]["id"],
                            provider: Provider.of<ProfileWallProvider>(context,
                                    listen: false)
                                .profileWalls[index]["wallpaper_provider"]
                                .toString(),
                            url: Provider.of<ProfileWallProvider>(context,
                                    listen: false)
                                .profileWalls[index]["wallpaper_url"],
                            thumbUrl: Provider.of<ProfileWallProvider>(context,
                                    listen: false)
                                .profileWalls[index]["wallpaper_thumb"])
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: Stack(
              children: <Widget>[
                AnimatedBuilder(
                    animation: offsetAnimation,
                    builder: (buildContext, child) {
                      if (offsetAnimation.value < 0.0)
                        print('${offsetAnimation.value + 8.0}');
                      return GestureDetector(
                        child: CachedNetworkImage(
                          imageUrl: Provider.of<ProfileWallProvider>(context,
                                  listen: false)
                              .profileWalls[index]["wallpaper_url"],
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
                          placeholder: (context, url) => Stack(
                            children: <Widget>[
                              SizedBox.expand(child: Text("")),
                              Container(
                                child: Center(
                                  child: Loader(),
                                ),
                              ),
                            ],
                          ),
                          errorWidget: (context, url, error) => Container(
                            child: Center(
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
                        ),
                        onPanUpdate: (details) {
                          if (details.delta.dy < -10) {
                            panelController.open();
                            HapticFeedback.vibrate();
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
                          !isLoading ? updateAccent() : print("");
                          shakeController.forward(from: 0.0);
                        },
                      );
                    }),
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      onPressed: () {
                        navStack.removeLast();
                        print(navStack);
                        Navigator.pop(context);
                      },
                      color: isLoading
                          ? Theme.of(context).accentColor
                          : accent.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                      icon: Icon(
                        JamIcons.chevron_left,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      onPressed: () {
                        var link = Provider.of<ProfileWallProvider>(context,
                                listen: false)
                            .profileWalls[index]["wallpaper_url"];
                        Navigator.push(
                            context,
                            PageRouteBuilder(
                                transitionDuration: Duration(milliseconds: 300),
                                pageBuilder:
                                    (context, animation, secondaryAnimation) {
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
                      icon: Icon(
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
