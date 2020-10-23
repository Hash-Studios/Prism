import 'package:Prism/data/tabs/provider/tabsProvider.dart';
import 'package:Prism/global/categoryMenu.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/pages/home/wallpapers/homeScreen.dart';
import 'package:Prism/ui/pages/home/core/splashScreen.dart';
import 'package:Prism/ui/widgets/home/core/tutorials.dart';
import 'package:Prism/ui/widgets/popup/colorsPopUp.dart';
import 'package:Prism/ui/widgets/popup/tutorialCompletePopUp.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:Prism/ui/pages/home/core/pageManager.dart' as PM;
import 'package:Prism/global/globals.dart' as globals;
import 'package:tutorial_coach_mark/target_focus.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:Prism/main.dart' as main;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/config.dart' as config;

class CategoriesBar extends StatefulWidget {
  final double width;
  final double height;
  const CategoriesBar({Key key, @required this.width, @required this.height})
      : super(key: key);

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  bool isNew;
  bool noNotification = false;
  List<TargetFocus> targets = [];
  @override
  void initState() {
    isNew = true;
    super.initState();
    globals.height = widget.height;
    globals.width = widget.width;
    initTargets(targets, widget.width, widget.height);
    if (!globals.updateChecked) {
      _checkUpdate();
    }
    noNotification = checkNewNotification();
    if (isNew) {
      Future.delayed(const Duration()).then(
          (value) => WidgetsBinding.instance.addPostFrameCallback(afterLayout));
    }
  }

  String textSkip = "SKIP";
  void showTutorial() {
    TutorialCoachMark(context,
        targets: targets,
        colorShadow: config.Colors().mainAccentColor(1),
        textSkip: textSkip,
        paddingFocus: 1,
        opacityShadow: 0.9, finish: () {
      debugPrint("finish");
    }, clickTarget: (target) {
      debugPrint(target.identify.toString());
      if (target.identify == "Target 3") {
        setState(() {
          textSkip = "FINISH";
        });
      }
      if (target.identify == "Target 4") {
        Future.delayed(const Duration(milliseconds: 800))
            .then((value) => showTutorialComplete(context));
      }
    }, clickSkip: () {
      debugPrint("skip");
    })
      ..show();
  }

  void afterLayout(_) {
    final newDevice = main.prefs.get("newDevice");
    if (newDevice == null || newDevice == true) {
      Future.delayed(const Duration(milliseconds: 100), showTutorial);
      main.prefs.put("newDevice", false);
    } else {
      main.prefs.put("newDevice", false);
    }
  }

  Widget _wrapScrollTag({int index, Widget child}) => AutoScrollTag(
        key: ValueKey(index),
        controller: globals.categoryController,
        index: index,
        highlightColor: Colors.black.withOpacity(0.1),
        child: child,
      );
  bool checkNewNotification() {
    final Box<List> box = Hive.box('notifications');
    var notifications = box.get('notifications');
    notifications ??= [];
    if (notifications.isEmpty) {
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
    debugPrint("checking for update");
    try {
      debugPrint("Current App Version :$currentAppVersion");
      debugPrint("Latest Version :${remoteConfig.getString("currentVersion")}");
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
          final Box<List> box = Hive.box('notifications');
          for (final i in box.get('notifications') ?? []) {
            if (i.url ==
                "https://play.google.com/store/apps/details?id=com.hash.prism") {
              globals.updateAlerted = true;
            }
          }
          if (globals.updateAvailable) {
            if (!globals.updateAlerted) {
              writeNotifications({
                'notification': {
                  'title':
                      'New version ${globals.versionInfo["version_number"]} Available!',
                  'body': 'Update now available on the Google Play Store.',
                },
                'data': {
                  'imageUrl':
                      "https://thelifedesigncourse.com/wp-content/uploads/2019/05/orange-waves-background-fluid-gradient-vector-21996148.jpg",
                  'url':
                      "https://play.google.com/store/apps/details?id=com.hash.prism",
                }
              });
              Future.delayed(const Duration())
                  .then((value) => noNotification = checkNewNotification());
              final snackBar = SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text(
                    'New version ${globals.versionInfo["version_number"]} Available!'),
                action: SnackBarAction(
                  label: 'VIEW',
                  textColor: config.Colors().mainAccentColor(1),
                  onPressed: () {
                    Navigator.pushNamed(context, notificationsRoute);
                  },
                ),
              );
              Scaffold.of(context).showSnackBar(snackBar);
            } else {
              debugPrint("Updated is alreday alerted!");
            }
          } else {
            debugPrint("No update");
          }
        } else {
          setState(() {
            globals.updateAvailable = false;
          });
        }
      });
    } catch (e) {
      debugPrint("Error while checking for updates! :$e");
    }
    setState(() {
      globals.updateChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
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
                  ? const Icon(JamIcons.bell)
                  : Stack(children: <Widget>[
                      const Icon(JamIcons.bell_f),
                      Positioned(
                        top: 0.0,
                        right: 0.0,
                        child: Icon(
                          Icons.brightness_1,
                          size: 9.0,
                          color: config.Colors().mainAccentColor(1),
                        ),
                      )
                    ]),
              onPressed: () {
                setState(() {
                  noNotification = true;
                });
                Navigator.pushNamed(context, notificationsRoute);
              },
            ),
          ),
          SizedBox(
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
                    child: Stack(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 300),
                            firstCurve: Curves.easeIn,
                            secondCurve: Curves.easeIn,
                            secondChild: ActionChip(
                                backgroundColor: Theme.of(context).hintColor,
                                pressElevation: 5,
                                padding:
                                    const EdgeInsets.fromLTRB(14, 11, 14, 11),
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
                                          duration:
                                              const Duration(milliseconds: 200),
                                          curve: Curves.easeInCubic);
                                      break;
                                    case "Collections":
                                      PM.pageController.animateToPage(1,
                                          duration:
                                              const Duration(milliseconds: 200),
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
                                padding:
                                    const EdgeInsets.fromLTRB(14, 11, 14, 11),
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
              icon: const Icon(JamIcons.brush),
              onPressed: () {
                showColors(context);
              },
            ),
          ),
          SizedBox(
              width: MediaQuery.of(context).size.width * 0.1,
              height: 100,
              child: PopupMenuButton(
                icon: const Icon(JamIcons.more_vertical),
                elevation: 4,
                initialValue:
                    Provider.of<CategorySupplier>(context).selectedChoice,
                onCanceled: () {
                  debugPrint('You have not chossed anything');
                },
                tooltip: 'Categories',
                onSelected: (choice) {
                  Provider.of<CategorySupplier>(context, listen: false)
                      .changeSelectedChoice(choice as CategoryMenu);
                  Provider.of<CategorySupplier>(context, listen: false)
                      .changeWallpaperFuture(choice, "r");
                  PM.pageController.animateToPage(0,
                      duration: const Duration(milliseconds: 200),
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
                          Icon(choice.icon as IconData),
                          const SizedBox(width: 10),
                          Text(choice.name.toString()),
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
