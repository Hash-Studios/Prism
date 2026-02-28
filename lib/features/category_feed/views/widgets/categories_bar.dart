import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/features/category_feed/views/category_feed_bloc_adapter.dart';
import 'package:Prism/features/category_feed/views/popups/category_popup.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive_io/hive_io.dart';
import 'package:in_app_update/in_app_update.dart';

class CategoriesBar extends StatefulWidget {
  const CategoriesBar({super.key});

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      checkForUpdate();
    });
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
    // Avoid forcing an immediate-update flow during debug sessions because it
    // interrupts the running process and disconnects flutter run.
    if (kDebugMode) {
      return;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        logger.i('Update available. Skipping automatic immediate update at startup.');
      }
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(dynamic exception) {
    logger.d(exception.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (!app_state.tooltipShown) {
      Future.delayed(const Duration(seconds: 2)).then((_) {
        try {
          final dynamic tooltip = key.currentState;
          if (!noNotification && notifications.isNotEmpty) {
            tooltip.ensureTooltipVisible();
            app_state.tooltipShown = true;
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
            ? Icon(JamIcons.bell, color: Theme.of(context).colorScheme.secondary)
            : Tooltip(
                key: key,
                message: notifications.length != 1
                    ? "${notifications.length} new notifications!"
                    : "${notifications.length} new notification!",
                child: Stack(
                  children: <Widget>[
                    Icon(JamIcons.bell_f, color: Theme.of(context).colorScheme.secondary),
                    Positioned(
                      top: 0.0,
                      right: 0.0,
                      child: Icon(
                        Icons.brightness_1,
                        size: 9.0,
                        color: Theme.of(context).colorScheme.error == Colors.black
                            ? Colors.white24
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
        tooltip: 'Notifications',
        onPressed: () {
          setState(() {
            noNotification = true;
          });
          context.router.push(const NotificationRoute());
        },
      ),
      title: Align(
        child: SizedBox(
          height: 24,
          width: context.categoryCurrentChoice() == "Community" ? 110 : 260,
          child: context.categoryCurrentChoice() == "Community"
              ? SvgPicture.string(
                  prismTextLogo.replaceAll(
                    "black",
                    "#${Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2)}",
                  ),
                )
              : GestureDetector(
                  onTap: () {
                    analytics.track(const CategoriesCheckedEvent());
                    showCategories(context, context.categorySelectedChoice(listen: false));
                  },
                  child: Text(
                    context.categoryCurrentChoice()!.toUpperCase(),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(
                      fontFamily: "Proxima Nova",
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
        ),
      ),
      actions: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: CoinBalanceChip(sourceTag: 'coins.chip.categories_bar'),
        ),
        IconButton(
          icon: Icon(JamIcons.grid, color: Theme.of(context).colorScheme.secondary),
          onPressed: () {
            analytics.track(const CategoriesCheckedEvent());
            showCategories(context, context.categorySelectedChoice(listen: false));
          },
          tooltip: 'Categories',
        ),
      ],
    );
  }
}
