import 'dart:ui';

import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/config.dart' as config;

class SetupViewScreen extends StatefulWidget {
  final List arguments;
  const SetupViewScreen({this.arguments});

  @override
  _SetupViewScreenState createState() => _SetupViewScreenState();
}

class _SetupViewScreenState extends State<SetupViewScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int index;
  String thumb;
  bool isLoading = true;
  List<Color> colors;
  PanelController panelController = PanelController();
  AnimationController shakeController;
  bool panelCollapsed = true;

  @override
  void initState() {
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    index = widget.arguments[0] as int;
    isLoading = true;
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
        body: SlidingUpPanel(
          backdropEnabled: true,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: const [],
          collapsed: CollapsedPanel(panelCollapsed: panelCollapsed),
          minHeight: MediaQuery.of(context).size.height / 20,
          parallaxEnabled: true,
          parallaxOffset: 0.00,
          color: Colors.transparent,
          maxHeight: MediaQuery.of(context).size.height * .43,
          controller: panelController,
          onPanelOpened: () {
            setState(() {
              panelCollapsed = false;
            });
          },
          onPanelClosed: () {
            setState(() {
              panelCollapsed = true;
            });
          },
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
                          child: Icon(
                            JamIcons.chevron_down,
                            color: Theme.of(context).accentColor,
                          ),
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
                              padding: const EdgeInsets.fromLTRB(35, 0, 35, 5),
                              child: Text(
                                Provider.of<SetupProvider>(context,
                                        listen: false)
                                    .setups[index]["name"]
                                    .toString()
                                    .toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .headline1
                                    .copyWith(
                                        fontSize: 30,
                                        color: Theme.of(context).accentColor),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                              child: Text(
                                Provider.of<SetupProvider>(context,
                                        listen: false)
                                    .setups[index]["desc"]
                                    .toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .headline6
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                    child: Text(
                                      Provider.of<SetupProvider>(context,
                                              listen: false)
                                          .setups[index]["id"]
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
                                        JamIcons.google_play_circle,
                                        size: 20,
                                        color: Theme.of(context)
                                            .accentColor
                                            .withOpacity(.7),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.32,
                                        child: Text(
                                          Provider.of<SetupProvider>(context,
                                                  listen: false)
                                              .setups[index]["icon"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Row(
                                    children: [
                                      Provider.of<SetupProvider>(context,
                                                      listen: false)
                                                  .setups[index]["widget"] ==
                                              ""
                                          ? Container()
                                          : Icon(
                                              JamIcons.google_play,
                                              size: 20,
                                              color: Theme.of(context)
                                                  .accentColor
                                                  .withOpacity(.7),
                                            ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.32,
                                        child: Text(
                                          Provider.of<SetupProvider>(context,
                                                  listen: false)
                                              .setups[index]["widget"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
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
                                          label: Text(
                                            Provider.of<SetupProvider>(context,
                                                    listen: false)
                                                .setups[index]["by"]
                                                .toString(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 5, horizontal: 5),
                                          avatar: CircleAvatar(
                                            backgroundImage:
                                                CachedNetworkImageProvider(
                                                    Provider.of<SetupProvider>(
                                                            context,
                                                            listen: false)
                                                        .setups[index]
                                                            ["userPhoto"]
                                                        .toString()),
                                          ),
                                          labelPadding:
                                              const EdgeInsets.fromLTRB(
                                                  7, 3, 7, 3),
                                          onPressed: () {
                                            SystemChrome
                                                .setEnabledSystemUIOverlays([
                                              SystemUiOverlay.top,
                                              SystemUiOverlay.bottom
                                            ]);
                                            Navigator.pushNamed(context,
                                                photographerProfileRoute,
                                                arguments: [
                                                  Provider.of<SetupProvider>(
                                                          context,
                                                          listen: false)
                                                      .setups[index]["by"],
                                                  Provider.of<SetupProvider>(
                                                          context,
                                                          listen: false)
                                                      .setups[index]["email"],
                                                  Provider.of<SetupProvider>(
                                                              context,
                                                              listen: false)
                                                          .setups[index]
                                                      ["userPhoto"],
                                                  false,
                                                  Provider.of<SetupProvider>(
                                                                  context,
                                                                  listen: false)
                                                              .setups[index]
                                                          ["twitter"] ??
                                                      "",
                                                  Provider.of<SetupProvider>(
                                                                  context,
                                                                  listen: false)
                                                              .setups[index]
                                                          ["instagram"] ??
                                                      ""
                                                ]);
                                          }),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Text(
                                        Provider.of<SetupProvider>(context,
                                                listen: false)
                                            .setups[index]["wallpaper_provider"]
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
                      Provider.of<SetupProvider>(context, listen: false)
                                  .setups[index]["widget"] ==
                              ""
                          ? Expanded(
                              flex: 5,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  DownloadButton(
                                    link: Provider.of<SetupProvider>(context,
                                            listen: false)
                                        .setups[index]["wallpaper_url"]
                                        .toString(),
                                    colorChanged: false,
                                  ),
                                  SetWallpaperButton(
                                    url: Provider.of<SetupProvider>(context,
                                            listen: false)
                                        .setups[index]["wallpaper_url"]
                                        .toString(),
                                    colorChanged: false,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      launch(Provider.of<SetupProvider>(context,
                                              listen: false)
                                          .setups[index]["icon_url"]
                                          .toString());
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        boxShadow: [
                                          BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(.25),
                                              blurRadius: 4,
                                              offset: const Offset(0, 4))
                                        ],
                                        borderRadius:
                                            BorderRadius.circular(500),
                                      ),
                                      padding: const EdgeInsets.all(17),
                                      child: Icon(
                                        JamIcons.google_play_circle,
                                        color: Theme.of(context).accentColor,
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
                                    link: Provider.of<SetupProvider>(context,
                                            listen: false)
                                        .setups[index]["wallpaper_url"]
                                        .toString(),
                                    colorChanged: false,
                                  ),
                                  SetWallpaperButton(
                                    url: Provider.of<SetupProvider>(context,
                                            listen: false)
                                        .setups[index]["wallpaper_url"]
                                        .toString(),
                                    colorChanged: false,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      launch(Provider.of<SetupProvider>(context,
                                              listen: false)
                                          .setups[index]["icon_url"]
                                          .toString());
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        boxShadow: [
                                          BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(.25),
                                              blurRadius: 4,
                                              offset: const Offset(0, 4))
                                        ],
                                        borderRadius:
                                            BorderRadius.circular(500),
                                      ),
                                      padding: const EdgeInsets.all(17),
                                      child: Icon(
                                        JamIcons.google_play_circle,
                                        color: Theme.of(context).accentColor,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      launch(Provider.of<SetupProvider>(context,
                                              listen: false)
                                          .setups[index]["widget_url"]
                                          .toString());
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        boxShadow: [
                                          BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(.25),
                                              blurRadius: 4,
                                              offset: const Offset(0, 4))
                                        ],
                                        borderRadius:
                                            BorderRadius.circular(500),
                                      ),
                                      padding: const EdgeInsets.all(17),
                                      child: Icon(
                                        JamIcons.google_play,
                                        color: Theme.of(context).accentColor,
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
                      child: CachedNetworkImage(
                        imageUrl:
                            Provider.of<SetupProvider>(context, listen: false)
                                .setups[index]["image"]
                                .toString(),
                        imageBuilder: (context, imageProvider) => Hero(
                          tag: "CustomHerotag$index",
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                vertical: offsetAnimation.value * 1.25,
                                horizontal: offsetAnimation.value / 2),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(offsetAnimation.value),
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
                                : colors[0].computeLuminance() > 0.5
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
                  padding: const EdgeInsets.all(8.0),
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
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    onPressed: () {
                      createSetupDynamicLink(
                          index.toString(),
                          Provider.of<SetupProvider>(context, listen: false)
                              .setups[index]["name"]
                              .toString(),
                          Provider.of<SetupProvider>(context, listen: false)
                              .setups[index]["image"]
                              .toString());
                    },
                    color: isLoading
                        ? Theme.of(context).accentColor
                        : colors[0].computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                    icon: const Icon(
                      JamIcons.share_alt,
                    ),
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

class CollapsedPanel extends StatelessWidget {
  final bool panelCollapsed;
  const CollapsedPanel({
    Key key,
    this.panelCollapsed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 750),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        color: panelCollapsed
            ? Theme.of(context).primaryColor.withOpacity(1)
            : Theme.of(context).primaryColor.withOpacity(0),
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 30,
        child: Center(
            child: AnimatedOpacity(
          duration: const Duration(),
          opacity: panelCollapsed ? 1.0 : 0.0,
          child: Icon(
            JamIcons.chevron_up,
            color: Theme.of(context).accentColor,
          ),
        )),
      ),
    );
  }
}
