import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/categoryPopUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive/hive.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:provider/provider.dart';

class CategoriesBar extends StatefulWidget {
  const CategoriesBar({
    Key? key,
  }) : super(key: key);

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  bool noNotification = true;
  final Box<InAppNotif> box = Hive.box('inAppNotifs');
  List notifications = [];
  final key = GlobalKey();
  @override
  void initState() {
    if (main.prefs.get("Subscriber", defaultValue: true) as bool) {
      fetchNotifications();
    } else {
      noNotification = true;
    }
    super.initState();
    checkForUpdate();
  }

  Future<void> fetchNotifications() async {
    setState(() {
      notifications = box.values.toList();
    });
    checkNewNotification();
  }

  void checkNewNotification() {
    final Box<InAppNotif> box = Hive.box('inAppNotifs');
    notifications = box.values.toList();
    notifications.removeWhere((element) => element.read == true);
    if (notifications.isEmpty) {
      setState(() {
        noNotification = true;
      });
    } else {
      setState(() {
        noNotification = false;
      });
    }
  }

  //Check for update if available
  Future<void> checkForUpdate() async {
    InAppUpdate.checkForUpdate().then((info) {
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        InAppUpdate.performImmediateUpdate().catchError((e) => _showError(e));
      }
    }).catchError((e) {
      _showError(e);
    });
  }

  void _showError(dynamic exception) {
    logger.d(exception.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (!globals.tooltipShown) {
      Future.delayed(const Duration(seconds: 2)).then((_) {
        try {
          final dynamic tooltip = key.currentState;
          if (!noNotification && notifications.isNotEmpty) {
            tooltip.ensureTooltipVisible();
            globals.tooltipShown = true;
          }
          if (!noNotification && notifications.isNotEmpty) {
            Future.delayed(const Duration(seconds: 5)).then((_) {
              tooltip.deactivate();
            });
          }
        } catch (e) {
          logger.d(e.toString());
        }
      });
    }
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      titleSpacing: 0,
      centerTitle: true,
      leading: IconButton(
        icon: noNotification
            ? Icon(
                JamIcons.bell,
                color: Theme.of(context).accentColor,
              )
            : Tooltip(
                key: key,
                message: notifications.length != 1
                    ? "${notifications.length} new notifications!"
                    : "${notifications.length} new notification!",
                child: Stack(children: <Widget>[
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
                      color: Theme.of(context).errorColor == Colors.black
                          ? Colors.white24
                          : Theme.of(context).errorColor,
                    ),
                  )
                ]),
              ),
        tooltip: 'Notifications',
        onPressed: () {
          setState(() {
            noNotification = true;
          });
          Navigator.pushNamed(context, notificationsRoute);
        },
      ),
      title: Align(
        child: SizedBox(
          height: 24,
          width: Provider.of<CategorySupplier>(context).getCurrentChoice ==
                  "Community"
              ? 110
              : 260,
          child: Provider.of<CategorySupplier>(context).getCurrentChoice ==
                  "Community"
              ? SvgPicture.string(
                  prismTextLogo.replaceAll(
                    "black",
                    "#${Theme.of(context).accentColor.value.toRadixString(16).toString().substring(2)}",
                  ),
                )
              : GestureDetector(
                  onTap: () {
                    analytics.logEvent(
                      name: 'categories_checked',
                    );
                    showCategories(
                        context,
                        Provider.of<CategorySupplier>(context, listen: false)
                            .selectedChoice);
                  },
                  child: Text(
                    Provider.of<CategorySupplier>(context)
                        .getCurrentChoice!
                        .toUpperCase(),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.headline3!.copyWith(
                          fontFamily: "Proxima Nova",
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).accentColor,
                        ),
                  ),
                ),
        ),
      ),
      actions: [
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
