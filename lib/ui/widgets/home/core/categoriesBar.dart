import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/categoryPopUp.dart';
import 'package:Prism/ui/widgets/popup/colorsPopUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive/hive.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:provider/provider.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/ui/pages/home/core/pageManager.dart' as PM;

class CategoriesBar extends StatefulWidget {
  const CategoriesBar({
    Key key,
  }) : super(key: key);

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  bool noNotification = false;
  @override
  void initState() {
    fetchNotifications();
    super.initState();
    checkForUpdate();
    noNotification = checkNewNotification();
  }

  Future<void> fetchNotifications() async {
    await getNotifications();
    setState(() {});
  }

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
          height: 26,
          width: Provider.of<CategorySupplier>(context).getCurrentChoice ==
                  "Community"
              ? 110
              : 200,
          child: Provider.of<CategorySupplier>(context).getCurrentChoice ==
                  "Community"
              ? SvgPicture.string(
                  prismTextLogo.replaceAll(
                    "black",
                    "#${Theme.of(context).accentColor.value.toRadixString(16).toString().substring(2)}",
                  ),
                )
              : Text(
                  "   ${Provider.of<CategorySupplier>(context).getCurrentChoice}"
                      .toUpperCase(),
                  maxLines: 1,
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.fade,
                  style: Theme.of(context).textTheme.headline3.copyWith(
                        fontFamily: "Proxima Nova",
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).accentColor,
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
            analytics.logEvent(
              name: 'colorbrush_tapped',
            );
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
          tooltip: 'Notifications',
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
            analytics.logEvent(
              name: 'categories_checked',
            );
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
