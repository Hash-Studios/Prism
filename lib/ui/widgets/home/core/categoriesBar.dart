import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/data/tabs/provider/tabsProvider.dart';
import 'package:Prism/global/categoryMenu.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/home/core/tutorials.dart';
import 'package:Prism/ui/widgets/popup/categoryPopUp.dart';
import 'package:Prism/ui/widgets/popup/colorsPopUp.dart';
import 'package:Prism/ui/widgets/popup/tutorialCompletePopUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive/hive.dart';
import 'package:in_app_update/in_app_update.dart';
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
    fetchNotifications();
    super.initState();
    globals.height = widget.height;
    globals.width = widget.width;
    initTargets(targets, widget.width, widget.height);
    checkForUpdate();
    noNotification = checkNewNotification();
    if (isNew) {
      Future.delayed(const Duration()).then(
          (value) => WidgetsBinding.instance.addPostFrameCallback(afterLayout));
    }
  }

  Future<void> fetchNotifications() async {
    await getNotifications();
    setState(() {});
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
    }).show();
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
  Future<void> checkForUpdate() async {
    InAppUpdate.checkForUpdate().then((info) {
      if (info.updateAvailable == true) {
        InAppUpdate.performImmediateUpdate().catchError((e) => _showError(e));
      }
    }).catchError((e) => _showError(e));
  }

  void _showError(dynamic exception) {
    debugPrint(exception.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      titleSpacing: 0,
      title: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 30,
          width: 120,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SvgPicture.string(
              prismTextLogo.replaceAll(
                "black",
                "#${Theme.of(context).accentColor.value.toRadixString(16).toString().substring(2)}",
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            JamIcons.brush,
            color: Theme.of(context).accentColor,
          ),
          tooltip: 'Search by color',
          onPressed: () {
            showColors(context);
          },
        ),
        IconButton(
          icon: noNotification
              ? Icon(
                  JamIcons.bell,
                  color: Theme.of(context).accentColor,
                )
              : Stack(children: <Widget>[
                  Icon(
                    JamIcons.bell_f,
                    color: Theme.of(context).accentColor,
                  ),
                  Positioned(
                    top: 0.0,
                    right: 0.0,
                    child: Icon(
                      Icons.brightness_1,
                      size: 9.0,
                      color: config.Colors().mainAccentColor(1) == Colors.black
                          ? const Color(0xFFE57697)
                          : config.Colors().mainAccentColor(1),
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
        IconButton(
          icon: Icon(
            JamIcons.grid,
            color: Theme.of(context).accentColor,
          ),
          onPressed: () {
            showCategories(
                context,
                Provider.of<CategorySupplier>(context, listen: false)
                    .selectedChoice);
          },
          tooltip: 'Categories',
        )
      ],
    );
  }
}
