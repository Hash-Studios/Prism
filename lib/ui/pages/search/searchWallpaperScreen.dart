import 'dart:io';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as WData;
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
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:screenshot/screenshot.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class SearchWallpaperScreen extends StatefulWidget {
  final List arguments;
  SearchWallpaperScreen({@required this.arguments});
  @override
  _SearchWallpaperScreenState createState() => _SearchWallpaperScreenState();
}

class _SearchWallpaperScreenState extends State<SearchWallpaperScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    return true;
  }

  List<TargetFocus> targets = List();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String selectedProvider;
  String query;
  int index;
  String link;
  AnimationController shakeController;
  bool isLoading = true;
  PaletteGenerator paletteGenerator;
  List<Color> colors;
  Color accent;
  bool colorChanged = false;
  File _imageFile;
  bool screenshotTaken = false;
  ScreenshotController screenshotController = ScreenshotController();
  PanelController panelController = PanelController();
  bool panelClosed = true;

  Future<void> _updatePaletteGenerator() async {
    setState(() {
      isLoading = true;
    });
    paletteGenerator = await PaletteGenerator.fromImageProvider(
      new CachedNetworkImageProvider(link),
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
    // print("Wallpaper Screen");
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([]);
    selectedProvider = widget.arguments[0];
    query = widget.arguments[1];
    index = widget.arguments[2];
    link = widget.arguments[3];
    isLoading = true;
    _updatePaletteGenerator();
  }

  void UnsecureWindow() async {
    await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    print("Disabled Secure flags");
  }

  @override
  void dispose() {
    super.dispose();
    shakeController.dispose();
    UnsecureWindow();
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
      child: selectedProvider == "WallHaven"
          ? Scaffold(
              resizeToAvoidBottomPadding: false,
              key: _scaffoldKey,
              backgroundColor:
                  isLoading ? Theme.of(context).primaryColor : accent,
              body: SlidingUpPanel(
                onPanelOpened: () {
                  if (panelClosed) {
                    print('Screenshot Starting');
                    setState(() {
                      panelClosed = false;
                    });
                    screenshotController
                        .capture(
                      pixelRatio: 3,
                      delay: Duration(milliseconds: 10),
                    )
                        .then((File image) async {
                      setState(() {
                        _imageFile = image;
                        screenshotTaken = true;
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
                  height: MediaQuery.of(context).size.height * .46,
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
                          padding: const EdgeInsets.fromLTRB(35, 0, 35, 15),
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
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                    child: Text(
                                      WData.wallsS[index].id
                                          .toString()
                                          .toUpperCase(),
                                      style:
                                          Theme.of(context).textTheme.bodyText1,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        JamIcons.eye,
                                        size: 20,
                                        color: Colors.white70,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        "${WData.wallsS[index].views.toString()}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText2,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(
                                        JamIcons.heart_f,
                                        size: 20,
                                        color: Colors.white70,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        "${WData.wallsS[index].favourites.toString()}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText2,
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
                                        "${double.parse(((double.parse(WData.wallsS[index].file_size.toString()) / 1000000).toString())).toStringAsFixed(2)} MB",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText2,
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
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 0, 0, 0),
                                    child: Row(
                                      children: [
                                        Text(
                                          WData.wallsS[index].category
                                                  .toString()[0]
                                                  .toUpperCase() +
                                              WData.wallsS[index].category
                                                  .toString()
                                                  .substring(1),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2,
                                        ),
                                        SizedBox(width: 10),
                                        Icon(
                                          JamIcons.unordered_list,
                                          size: 20,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Text(
                                        "${WData.wallsS[index].resolution.toString()}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText2,
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
                                        query.toString()[0].toUpperCase() +
                                            query.toString().substring(1),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText2,
                                      ),
                                      SizedBox(width: 10),
                                      Icon(
                                        JamIcons.search,
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
                                  : WData.wallsS[index].path.toString(),
                            ),
                            SetWallpaperButton(
                                colorChanged: colorChanged,
                                url: screenshotTaken
                                    ? _imageFile.path
                                    : WData.wallsS[index].path),
                            FavouriteWallpaperButton(
                              id: WData.wallsS[index].id.toString(),
                              provider: "WallHaven",
                              wallhaven: WData.wallsS[index],
                              trash: false,
                            ),
                            ShareButton(
                                id: WData.wallsS[index].id,
                                provider: "WallHaven",
                                url: WData.wallsS[index].path,
                                thumbUrl:
                                    WData.wallsS[index].thumbs["original"])
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
                              imageUrl: WData.wallsS[index].path,
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
                                HapticFeedback.vibrate();
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
                            var link = WData.wallsS[index].path;
                            Navigator.push(
                                context,
                                PageRouteBuilder(
                                    transitionDuration:
                                        Duration(milliseconds: 300),
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
                          icon: Icon(
                            JamIcons.clock,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          : Scaffold(
              resizeToAvoidBottomPadding: false,
              key: _scaffoldKey,
              backgroundColor:
                  isLoading ? Theme.of(context).primaryColor : accent,
              body: SlidingUpPanel(
                onPanelOpened: () {
                  if (panelClosed) {
                    print('Screenshot Starting');
                    setState(() {
                      panelClosed = false;
                    });
                    screenshotController
                        .capture(
                      pixelRatio: 3,
                      delay: Duration(milliseconds: 10),
                    )
                        .then((File image) async {
                      setState(() {
                        _imageFile = image;
                        screenshotTaken = true;
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
                  height: MediaQuery.of(context).size.height * .46,
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
                          padding: const EdgeInsets.fromLTRB(35, 0, 35, 15),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                child: Container(
                                  width: MediaQuery.of(context).size.width * .8,
                                  child: Text(
                                    PData.wallsPS[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length > 8
                                        ? PData.wallsPS[index].url
                                                .toString()
                                                .replaceAll(
                                                    "https://www.pexels.com/photo/", "")
                                                .replaceAll("-", " ")
                                                .replaceAll("/", "")[0]
                                                .toUpperCase() +
                                            PData.wallsPS[index].url
                                                .toString()
                                                .replaceAll(
                                                    "https://www.pexels.com/photo/", "")
                                                .replaceAll("-", " ")
                                                .replaceAll("/", "")
                                                .substring(
                                                    1,
                                                    PData.wallsPS[index].url
                                                            .toString()
                                                            .replaceAll(
                                                                "https://www.pexels.com/photo/", "")
                                                            .replaceAll(
                                                                "-", " ")
                                                            .replaceAll("/", "")
                                                            .length -
                                                        7)
                                        : PData.wallsPS[index].url
                                                .toString()
                                                .replaceAll(
                                                    "https://www.pexels.com/photo/", "")
                                                .replaceAll("-", " ")
                                                .replaceAll("/", "")[0]
                                                .toUpperCase() +
                                            PData.wallsPS[index].url
                                                .toString()
                                                .replaceAll(
                                                    "https://www.pexels.com/photo/",
                                                    "")
                                                .replaceAll("-", " ")
                                                .replaceAll("/", "")
                                                .substring(1),
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Icon(
                                            JamIcons.camera,
                                            size: 20,
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: 10),
                                          Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                .4,
                                            child: Text(
                                              PData.wallsPS[index].photographer
                                                  .toString(),
                                              textAlign: TextAlign.left,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Icon(
                                            JamIcons.set_square,
                                            size: 20,
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            "${PData.wallsPS[index].width.toString()}x${PData.wallsPS[index].height.toString()}",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2,
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
                                            PData.wallsPS[index].id.toString(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2,
                                          ),
                                          SizedBox(width: 10),
                                          Icon(
                                            JamIcons.info,
                                            size: 20,
                                            color: Colors.white70,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Text(
                                            query.toString(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2,
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
                                    : PData.wallsPS[index].src["original"]
                                        .toString()),
                            SetWallpaperButton(
                                colorChanged: colorChanged,
                                url: screenshotTaken
                                    ? _imageFile.path
                                    : PData.wallsPS[index].src["original"]),
                            FavouriteWallpaperButton(
                              id: PData.wallsPS[index].id.toString(),
                              provider: "Pexels",
                              pexels: PData.wallsPS[index],
                              trash: false,
                            ),
                            ShareButton(
                                id: PData.wallsPS[index].id,
                                provider: selectedProvider,
                                url: PData.wallsPS[index].src["original"],
                                thumbUrl: PData.wallsPS[index].src["medium"])
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
                              imageUrl: PData.wallsPS[index].src["original"],
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
                                HapticFeedback.vibrate();
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
                            var link = PData.wallsPS[index].src["original"];
                            Navigator.push(
                                context,
                                PageRouteBuilder(
                                    transitionDuration:
                                        Duration(milliseconds: 300),
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
                          icon: Icon(
                            JamIcons.clock,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
    // } catch (e) {
    //   print(e.toString());
    //   String route = currentRoute;
    // currentRoute = previousRoute;
    // previousRoute = route;
    // print(currentRoute);
    // Navigator.pop(context);
    //   return Container();
    // }
  }
}
