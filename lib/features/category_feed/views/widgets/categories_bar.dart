import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:in_app_update/in_app_update.dart';

class CategoriesBar extends StatefulWidget {
  const CategoriesBar({super.key});

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  final NotificationsLocalDataSource _notificationsLocal = getIt<NotificationsLocalDataSource>();
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool noNotification = true;
  List<InAppNotificationEntity> notifications = <InAppNotificationEntity>[];
  final key = GlobalKey();
  @override
  void initState() {
    if (_settingsLocal.get<bool>("Subscriber", defaultValue: true)) {
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
    final all = await _notificationsLocal.readAll();
    setState(() {
      notifications = all;
    });
    await checkNewNotification();
  }

  Future<void> checkNewNotification() async {
    notifications = (await _notificationsLocal.readAll()).where((element) => !element.read).toList(growable: false);
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
          width: 110,
          child: SvgPicture.string(
            prismTextLogo.replaceAll(
              "black",
              "#${Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2)}",
            ),
          ),
        ),
      ),
      actions: const [],
    );
  }
}
