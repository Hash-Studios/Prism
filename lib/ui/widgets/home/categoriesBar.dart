import 'package:Prism/data/tabs/provider/tabsProvider.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/pages/home/homeScreen.dart';
import 'package:Prism/ui/pages/home/splashScreen.dart';
import 'package:Prism/ui/widgets/popup/colorsPopUp.dart';
import 'package:Prism/ui/widgets/popup/tutorialCompletePopUp.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:Prism/ui/pages/home/pageManager.dart' as PM;
import 'package:Prism/global/globals.dart' as globals;
import 'package:tutorial_coach_mark/animated_focus_light.dart';
import 'package:tutorial_coach_mark/content_target.dart';
import 'package:tutorial_coach_mark/target_focus.dart';
import 'package:tutorial_coach_mark/target_position.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:Prism/main.dart' as main;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:Prism/routes/routing_constants.dart';

class CategoriesBar extends StatefulWidget {
  final width;
  final height;
  CategoriesBar({Key key, @required this.width, @required this.height})
      : super(key: key);

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  bool isNew;
  bool noNotification = false;
  List<TargetFocus> targets = List();
  @override
  void initState() {
    isNew = true;
    super.initState();
    globals.height = widget.height;
    initTargets();
    if (!globals.updateChecked) {
      _checkUpdate();
    }
    noNotification = checkNewNotification();
    if (isNew) {
      Future.delayed(Duration(seconds: 0)).then(
          (value) => WidgetsBinding.instance.addPostFrameCallback(afterLayout));
    }
  }

  void initTargets() {
    targets.add(TargetFocus(
      identify: "Target 0",
      targetPosition: TargetPosition(Size(0, 0), Offset(0, 0)),
      contents: [
        ContentTarget(
            align: AlignContent.bottom,
            child: SizedBox(
              height: widget.height,
              child: Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      "Hey! Welcome to Prism.",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20.0),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: RichText(
                        text: TextSpan(
                          text:
                              "➡ Let's start your beautiful journey with a quick intro.\n\n➡ Tap anywhere on the screen to continue.",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ))
      ],
      shape: ShapeLightFocus.Circle,
    ));
    targets.add(TargetFocus(
      identify: "Target 1",
      targetPosition: TargetPosition(Size(widget.width, 60), Offset(0, 20)),
      contents: [
        ContentTarget(
            align: AlignContent.bottom,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the Categories Bar.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: RichText(
                      text: TextSpan(
                          text: "➡ Find all wallpaper categories like ",
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(
                              text:
                                  "Curated, 4k, Abstract, Nature, Art, Minimal ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: "etc, here.\n\n"),
                            TextSpan(text: "➡ It also has a "),
                            TextSpan(
                              text: "Colors ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text:
                                    "button, which lets you find wallpapers by a specific color.\n\n"),
                          ]),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
    targets.add(TargetFocus(
      identify: "Target 2",
      targetPosition: TargetPosition(
          Size(widget.width, widget.height - 400), Offset(0, 70)),
      contents: [
        ContentTarget(
            align: AlignContent.bottom,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the Wallpapers Feed.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: RichText(
                      text: TextSpan(
                          text: "➡ Swipe ",
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(
                              text: "vertically ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text:
                                    "to see all the wallpapers in a category.\n\n"),
                            TextSpan(text: "➡ Swipe "),
                            TextSpan(
                              text: "horizontally ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text:
                                    "to switch between different categories.\n\n"),
                          ]),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
    targets.add(TargetFocus(
      targetPosition: TargetPosition(
          Size(widget.width * 0.5, widget.width * 0.5 / 0.6625), Offset(0, 70)),
      identify: "Target 3",
      contents: [
        ContentTarget(
            align: AlignContent.bottom,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Tap on a wallpaper to view it.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: RichText(
                      text: TextSpan(
                          text: "➡ You can also ",
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(
                              text: "apply, favorite,",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " and"),
                            TextSpan(
                              text: " download",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text: " it directly from the 3-dots menu.\n\n"),
                            TextSpan(text: "➡ You can also "),
                            TextSpan(
                              text: "tap and hold ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text:
                                    "any wallpaper to quickly copy its sharing link.\n\n"),
                          ]),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
    targets.add(TargetFocus(
      targetPosition: TargetPosition(Size(widget.width * 0.7, 100),
          Offset(widget.width * 0.15, widget.height - 100)),
      identify: "Target 4",
      contents: [
        ContentTarget(
            align: AlignContent.top,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the navigation bar.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: RichText(
                      text: TextSpan(
                          text: "➡ Here you can access your ",
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(
                              text: "favorites, downloads,",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " and"),
                            TextSpan(
                              text: " search",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " for more wallpapers.\n\n"),
                            TextSpan(text: "➡ You can also upload your own "),
                            TextSpan(
                              text: "wallpapers ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: "from here.\n\n"),
                            TextSpan(text: "➡ You can also access your "),
                            TextSpan(
                              text: "profile ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: "from here.\n\n"),
                          ]),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
  }

  void showTutorial() {
    TutorialCoachMark(context,
        targets: targets,
        colorShadow: Color(0xFFE57697),
        textSkip: "SKIP",
        paddingFocus: 1,
        opacityShadow: 0.9, finish: () {
      print("finish");
    }, clickTarget: (target) {
      print(target.identify);
      if (target.identify == "Target 4") {
        Future.delayed(Duration(milliseconds: 500))
            .then((value) => showTutorialComplete(context));
      }
    }, clickSkip: () {
      print("skip");
    })
      ..show();
  }

  void afterLayout(_) {
    var newApp = main.prefs.get("newApp");
    if (newApp == null || newApp == true) {
      Future.delayed(Duration(milliseconds: 100), showTutorial);
      main.prefs.put("newApp", false);
    } else {
      main.prefs.put("newApp", false);
    }
  }

  Widget _wrapScrollTag({int index, Widget child}) => AutoScrollTag(
        key: ValueKey(index),
        controller: globals.categoryController,
        index: index,
        child: child,
        highlightColor: Colors.black.withOpacity(0.1),
      );
  bool checkNewNotification() {
    Box<List> box = Hive.box('notifications');
    var notifications = box.get('notifications');
    if (notifications == null) {
      notifications = [];
    }
    if (notifications.length == 0) {
      setState(() {
        noNotification = true;
      });
      return true;
    } else {
      setState(() {
        noNotification = false;
      });
      return false;
    }
  }

  //Check for update if available
  String currentAppVersion = globals.currentAppVersion;
  Future<void> _checkUpdate() async {
    print("checking for update");
    try {
      print("Current App Version :" + currentAppVersion);
      print("Latest Version :" +
          remoteConfig.getString("currentVersion").toString());
      setState(() {
        if (currentAppVersion !=
            remoteConfig.getString("currentVersion").toString()) {
          setState(() {
            globals.updateAvailable = true;
            globals.versionInfo = {
              "version_number":
                  remoteConfig.getString("currentVersion").toString(),
              "version_desc": remoteConfig.getString("versionDesc").toString(),
            };
          });
          Box<List> box = Hive.box('notifications');
          for (var i in box.get('notifications') ?? []) {
            if (i.url ==
                "https://play.google.com/store/apps/details?id=com.hash.prism") {
              globals.updateAlerted = true;
            }
          }
          if (globals.updateAvailable) {
            if (!globals.updateAlerted) {
              writeNotifications({
                'notification': {
                  'title': 'New version ' +
                      globals.versionInfo["version_number"] +
                      ' Available!',
                  'body': 'Update now available on the Google Play Store.',
                },
                'data': {
                  'imageUrl':
                      "https://thelifedesigncourse.com/wp-content/uploads/2019/05/orange-waves-background-fluid-gradient-vector-21996148.jpg",
                  'url':
                      "https://play.google.com/store/apps/details?id=com.hash.prism",
                }
              });
              Future.delayed(Duration(seconds: 0))
                  .then((value) => noNotification = checkNewNotification());
              final snackBar = SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text('New version ' +
                    globals.versionInfo["version_number"] +
                    ' Available!'),
                action: SnackBarAction(
                  label: 'VIEW',
                  textColor: Color(0xFFE57697),
                  onPressed: () {
                    Navigator.pushNamed(context, NotificationsRoute);
                  },
                ),
              );
              Scaffold.of(context).showSnackBar(snackBar);
            } else {
              print("Updated is alreday alerted!");
            }
          } else {
            print("No update");
          }
        } else {
          setState(() {
            globals.updateAvailable = false;
          });
        }
      });
    } catch (e) {
      print("Error while checking for updates! :" + e.toString());
    }
    setState(() {
      globals.updateChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      excludeHeaderSemantics: false,
      automaticallyImplyLeading: false,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.1,
            height: 100,
            child: IconButton(
              icon: noNotification
                  ? Icon(JamIcons.bell)
                  : Stack(children: <Widget>[
                      Icon(JamIcons.bell_f),
                      Positioned(
                        top: 0.0,
                        right: 0.0,
                        child: Icon(
                          Icons.brightness_1,
                          size: 9.0,
                          color: Color(0xFFE57697),
                        ),
                      )
                    ]),
              onPressed: () {
                setState(() {
                  noNotification = true;
                });
                // showUpdate(context);
                Navigator.pushNamed(context, NotificationsRoute);
              },
            ),
          ),
          SizedBox(
            // key: globals.keyCategoriesBar,
            width: MediaQuery.of(context).size.width * 0.7,
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              controller: globals.categoryController,
              itemCount: Provider.of<TabProvider>(context).tabs.length,
              itemBuilder: (context, index) {
                return _wrapScrollTag(
                  index: index,
                  child: Align(
                    alignment: Alignment.center,
                    child: Stack(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: AnimatedCrossFade(
                            duration: Duration(milliseconds: 300),
                            firstCurve: Curves.easeIn,
                            secondCurve: Curves.easeIn,
                            secondChild: ActionChip(
                                backgroundColor: Theme.of(context).hintColor,
                                pressElevation: 5,
                                padding: EdgeInsets.fromLTRB(14, 11, 14, 11),
                                label: Text(
                                    Provider.of<TabProvider>(context)
                                        .tabs[index],
                                    style:
                                        Theme.of(context).textTheme.headline4),
                                onPressed: () {
                                  switch (Provider.of<TabProvider>(context,
                                          listen: false)
                                      .tabs[index]) {
                                    case "Wallpapers":
                                      PM.pageController.animateToPage(0,
                                          duration: Duration(milliseconds: 200),
                                          curve: Curves.easeInCubic);
                                      break;
                                    case "Collections":
                                      PM.pageController.animateToPage(1,
                                          duration: Duration(milliseconds: 200),
                                          curve: Curves.easeInCubic);
                                      break;
                                    default:
                                      break;
                                  }
                                }),
                            crossFadeState:
                                Provider.of<TabProvider>(context).tabs[index] ==
                                        Provider.of<TabProvider>(context)
                                            .selectedTab
                                    ? CrossFadeState.showFirst
                                    : CrossFadeState.showSecond,
                            firstChild: ActionChip(
                                pressElevation: 5,
                                padding: EdgeInsets.fromLTRB(14, 11, 14, 11),
                                backgroundColor: Theme.of(context).accentColor,
                                label: Text(
                                    Provider.of<TabProvider>(context)
                                        .tabs[index],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline4
                                        .copyWith(
                                            color: Theme.of(context)
                                                .primaryColor)),
                                onPressed: () {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.1,
            height: 100,
            child: IconButton(
              icon: Icon(JamIcons.brush),
              onPressed: () {
                showColors(context);
              },
            ),
          ),
          SizedBox(
              width: MediaQuery.of(context).size.width * 0.1,
              height: 100,
              child: PopupMenuButton(
                icon: Icon(JamIcons.more_vertical),
                elevation: 4,
                initialValue:
                    Provider.of<CategorySupplier>(context).selectedChoice,
                onCanceled: () {
                  print('You have not chossed anything');
                },
                tooltip: 'Categories',
                onSelected: (choice) {
                  Provider.of<CategorySupplier>(context, listen: false)
                      .changeSelectedChoice(choice);
                  Provider.of<CategorySupplier>(context, listen: false)
                      .changeWallpaperFuture(choice, "r");
                  PM.pageController.animateToPage(0,
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInCubic);
                },
                itemBuilder: (BuildContext context) {
                  return choices.map((choice) {
                    return PopupMenuItem(
                      textStyle: Theme.of(context)
                          .textTheme
                          .headline4
                          .copyWith(color: Theme.of(context).accentColor),
                      value: choice,
                      child: Row(
                        children: <Widget>[
                          Icon(choice.icon),
                          SizedBox(width: 10),
                          Text(choice.name),
                        ],
                      ),
                    );
                  }).toList();
                },
              ))
        ],
      ),
    );
  }
}
