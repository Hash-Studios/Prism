import 'package:Prism/data/setups/provider/setupProvider.dart' as SData;
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/config.dart' as config;

class ShareSetupViewScreen extends StatefulWidget {
  final List arguments;
  ShareSetupViewScreen({this.arguments});

  @override
  _ShareSetupViewScreenState createState() => _ShareSetupViewScreenState();
}

class _ShareSetupViewScreenState extends State<ShareSetupViewScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    navStack.removeLast();
    print(navStack);
    return true;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String name;
  String image;
  Future<Map> _future;
  bool isLoading = true;
  List<Color> colors;
  PanelController panelController = PanelController();
  AnimationController shakeController;

  @override
  void initState() {
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    name = widget.arguments[0];
    image = widget.arguments[1];
    _future = SData.getSetupFromName(name);
    isLoading = true;
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([]);
  }

  // getData() async {
  //   await SData.getSetupFromName(name).then((value) {
  //     setState(() {});
  //   });
  // }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
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
        backgroundColor: Theme.of(context).primaryColor,
        body: FutureBuilder(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
            print(snapshot.connectionState);
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return Center(child: new Loader());
              case ConnectionState.none:
                return Center(child: new Loader());
              case ConnectionState.active:
                return Center(child: new Loader());
              case ConnectionState.done:
                if (snapshot.hasError) {
                  return Center(child: new Loader());
                } else {
                  return SlidingUpPanel(
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
                          color: config.Colors().secondDarkColor(1)),
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
                    color: config.Colors().secondDarkColor(1),
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
                        color: config.Colors().secondDarkColor(1),
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
                          Expanded(
                            flex: 4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(35, 0, 35, 5),
                                  child: Text(
                                    name.toString().toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline1
                                        .copyWith(
                                            fontSize: 30, color: Colors.white),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(35, 0, 35, 0),
                                  child: Text(
                                    SData.setup["desc"].toString(),
                                    style:
                                        Theme.of(context).textTheme.headline6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
                              child: Row(
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
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            0, 5, 0, 10),
                                        child: Text(
                                          SData.setup["id"]
                                              .toString()
                                              .toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            JamIcons.google_play_circle,
                                            size: 20,
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: 10),
                                          Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.32,
                                            child: Text(
                                              "${SData.setup["icon"].toString()}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Row(
                                        children: [
                                          SData.setup["widget"] == ""
                                              ? Container()
                                              : Icon(
                                                  JamIcons.google_play,
                                                  size: 20,
                                                  color: Colors.white70,
                                                ),
                                          SizedBox(width: 10),
                                          Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.32,
                                            child: Text(
                                              "${SData.setup["widget"].toString()}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText2,
                                            ),
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
                                      ActionChip(
                                          label: Text(
                                            "${SData.setup["by"].toString()}",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                              vertical: 5, horizontal: 5),
                                          avatar: CircleAvatar(
                                            backgroundImage:
                                                CachedNetworkImageProvider(
                                                    SData.setup["userPhoto"]),
                                          ),
                                          labelPadding:
                                              EdgeInsets.fromLTRB(7, 3, 7, 3),
                                          onPressed: () {
                                            SystemChrome
                                                .setEnabledSystemUIOverlays([
                                              SystemUiOverlay.top,
                                              SystemUiOverlay.bottom
                                            ]);
                                            Navigator.pushNamed(context,
                                                PhotographerProfileRoute,
                                                arguments: [
                                                  SData.setup["by"],
                                                  SData.setup["email"],
                                                  SData.setup["userPhoto"]
                                                ]);
                                          }),
                                      SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Text(
                                            SData.setup["wallpaper_provider"]
                                                .toString(),
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
                            ),
                          ),
                          SData.setup["widget"] == ""
                              ? Expanded(
                                  flex: 5,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: <Widget>[
                                      DownloadButton(
                                        link: SData.setup["wallpaper_url"],
                                        colorChanged: false,
                                      ),
                                      SetWallpaperButton(
                                        url: SData.setup["wallpaper_url"],
                                        colorChanged: false,
                                      ),
                                      GestureDetector(
                                        onTap: () async {
                                          launch(SData.setup["icon_url"]);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).primaryColor,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(.25),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 4))
                                            ],
                                            borderRadius:
                                                BorderRadius.circular(500),
                                          ),
                                          padding: EdgeInsets.all(17),
                                          child: Icon(
                                            JamIcons.google_play_circle,
                                            color:
                                                Theme.of(context).accentColor,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Expanded(
                                  flex: 5,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: <Widget>[
                                      DownloadButton(
                                        link: SData.setup["wallpaper_url"],
                                        colorChanged: false,
                                      ),
                                      SetWallpaperButton(
                                        url: SData.setup["wallpaper_url"],
                                        colorChanged: false,
                                      ),
                                      GestureDetector(
                                        onTap: () async {
                                          launch(SData.setup["icon_url"]);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).primaryColor,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(.25),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 4))
                                            ],
                                            borderRadius:
                                                BorderRadius.circular(500),
                                          ),
                                          padding: EdgeInsets.all(17),
                                          child: Icon(
                                            JamIcons.google_play_circle,
                                            color:
                                                Theme.of(context).accentColor,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () async {
                                          launch(SData.setup["widget_url"]);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).primaryColor,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(.25),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 4))
                                            ],
                                            borderRadius:
                                                BorderRadius.circular(500),
                                          ),
                                          padding: EdgeInsets.all(17),
                                          child: Icon(
                                            JamIcons.google_play,
                                            color:
                                                Theme.of(context).accentColor,
                                            size: 30,
                                          ),
                                        ),
                                      )
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
                                  imageUrl: image,
                                  imageBuilder: (context, imageProvider) =>
                                      Hero(
                                    tag: "CustomHerotag$name",
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
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  progressIndicatorBuilder:
                                      (context, url, downloadProgress) => Stack(
                                    children: <Widget>[
                                      SizedBox.expand(child: Text("")),
                                      Container(
                                        child: Center(
                                          child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                config.Colors()
                                                    .mainAccentColor(1),
                                              ),
                                              value: downloadProgress.progress),
                                        ),
                                      ),
                                    ],
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    child: Center(
                                      child: Icon(
                                        JamIcons.close_circle_f,
                                        color: isLoading
                                            ? Theme.of(context).accentColor
                                            : colors[0].computeLuminance() > 0.5
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
                                  HapticFeedback.vibrate();
                                  shakeController.forward(from: 0.0);
                                },
                                onTap: () {
                                  HapticFeedback.vibrate();
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
                                  : colors[0].computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                              icon: Icon(
                                JamIcons.chevron_left,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                break;
              default:
                return Center(child: new CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
