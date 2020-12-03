import 'dart:typed_data';
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/data/notifications/model/notificationModel.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/ui/pages/home/wallpapers/homeScreen.dart' as home;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List notifications;
  @override
  void initState() {
    final Box<List> box = Hive.box('notifications');
    if (box.get('notifications') == [] || box.get('notifications') == null) {
      notifications = [];
    } else {
      notifications = box.get('notifications');
    }
    notifications = List.from(notifications.reversed);
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text("Notifications"),
          leading: IconButton(
            icon: const Icon(JamIcons.close),
            onPressed: () {
              if (navStack.length > 1) navStack.removeLast();
              debugPrint(navStack.toString());
              Navigator.pop(context);
            },
          ),
          actions: <Widget>[
            IconButton(
                icon: main.prefs.get("Subscriber") == false
                    ? const Icon(JamIcons.bell)
                    : const Icon(JamIcons.bell_off),
                onPressed: () {
                  final AlertDialog notificationsPopUp = AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    title: Text(
                      main.prefs.get("Subscriber") == false
                          ? 'Subscribe to notifications?'
                          : 'Unsubscribe to notifications?',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Theme.of(context).accentColor),
                    ),
                    actions: [
                      FlatButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        color: main.prefs.get("Subscriber") == false
                            ? config.Colors().mainAccentColor(1)
                            : Theme.of(context).hintColor,
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (main.prefs.get("Subscriber") == false) {
                            main.prefs.delete("Subscriber");
                            home.f.unsubscribeFromTopic('NoNotificationSquad');
                            toasts.codeSend("Succesfully Subscribed!");
                          } else {
                            main.prefs.put("Subscriber", false);
                            home.f.subscribeToTopic('NoNotificationSquad');
                            toasts.codeSend("Succesfully unsubscribed!");
                          }
                        },
                        child: const Text(
                          'YES',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      FlatButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        color: main.prefs.get("Subscriber") == false
                            ? Theme.of(context).hintColor
                            : config.Colors().mainAccentColor(1),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'NO',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    backgroundColor: Theme.of(context).primaryColor,
                    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  );

                  showModal(
                      context: context,
                      configuration: const FadeScaleTransitionConfiguration(),
                      builder: (BuildContext context) => notificationsPopUp);
                })
          ],
        ),
        body: Container(
          child: notifications.isNotEmpty
              ? ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Dismissible(
                      onDismissed: (DismissDirection direction) {
                        setState(() {
                          notifications.removeAt(index);
                        });
                        final Box<List> box = Hive.box('notifications');
                        box.put('notifications', notifications);
                      },
                      dismissThresholds: const {
                        DismissDirection.startToEnd: 0.5,
                        DismissDirection.endToStart: 0.5
                      },
                      secondaryBackground: Container(
                        color: Colors.red,
                        child: const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(JamIcons.trash),
                          ),
                        ),
                      ),
                      background: Container(
                        color: Colors.red,
                        child: const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(JamIcons.trash),
                          ),
                        ),
                      ),
                      key: UniqueKey(),
                      child: NotificationCard(
                          notification: notifications[index] as NotifData),
                    );
                  },
                )
              : Center(
                  child: Text('No new notifications',
                      style: TextStyle(color: Theme.of(context).accentColor))),
        ),
        floatingActionButton: notifications.isNotEmpty
            ? FloatingActionButton(
                mini: true,
                onPressed: () {
                  final AlertDialog deleteNotificationsPopUp = AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    title: Text(
                      'Delete all notifications?',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Theme.of(context).accentColor),
                    ),
                    actions: [
                      FlatButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        color: Theme.of(context).hintColor,
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() {
                            notifications = [];
                            final Box<List> box = Hive.box('notifications');
                            box.put('notifications', notifications);
                          });
                        },
                        child: const Text(
                          'YES',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      FlatButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        color: config.Colors().mainAccentColor(1),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'NO',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    backgroundColor: Theme.of(context).primaryColor,
                    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  );

                  showModal(
                      context: context,
                      configuration: const FadeScaleTransitionConfiguration(),
                      builder: (BuildContext context) =>
                          deleteNotificationsPopUp);
                },
                child: const Icon(JamIcons.trash),
              )
            : Container(),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotifData notification;

  const NotificationCard({this.notification});

  static String stringForDatetime(DateTime dt) {
    final dtInLocal = dt.toLocal();
    final now = DateTime.now().toLocal();
    var dateString = "";

    final diff = now.difference(dtInLocal);

    if (now.day == dtInLocal.day) {
      final todayFormat = DateFormat("h:mm a");
      dateString += todayFormat.format(dtInLocal);
    } else if ((diff.inDays) == 1 ||
        (diff.inSeconds < 86400 && now.day != dtInLocal.day)) {
      final yesterdayFormat = DateFormat("h:mm a");
      dateString += "Yesterday, ${yesterdayFormat.format(dtInLocal)}";
    } else if (now.year == dtInLocal.year && diff.inDays > 1) {
      final monthFormat = DateFormat("MMM d");
      dateString += monthFormat.format(dtInLocal);
    } else {
      final yearFormat = DateFormat("MMM d y");
      dateString += yearFormat.format(dtInLocal);
    }

    return dateString;
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const CircleAvatar(
        backgroundImage: AssetImage("assets/images/prism.png"),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      title: Text(
        notification.title,
        style: TextStyle(
            color: Theme.of(context).accentColor,
            fontWeight: FontWeight.w500,
            fontFamily: "Proxima Nova"),
      ),
      subtitle: Text(
        notification.desc,
        style: TextStyle(fontSize: 12, color: Theme.of(context).accentColor),
      ),
      children: <Widget>[
        InkWell(
          onTap: () {
            if (notification.url == "") {
              if (notification.pageName != null) {
                Navigator.pushNamed(context, notification.pageName,
                    arguments: notification.arguments);
              }
            } else {
              launch(notification.url);
            }
          },
          onLongPress: () {
            HapticFeedback.lightImpact();
          },
          child: Ink(
            child: Stack(
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                      Colors.black, BlendMode.saturation),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width * 9 / 16,
                    child: CachedNetworkImage(
                      imageUrl: notification.imageUrl ??
                          "https://w.wallhaven.cc/full/q6/wallhaven-q6mg5d.jpg",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width * 9 / 16,
                  child: CachedNetworkImage(
                    imageUrl: notification.imageUrl ??
                        "https://w.wallhaven.cc/full/q6/wallhaven-q6mg5d.jpg",
                    fit: BoxFit.contain,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      stringForDatetime(notification.createdAt),
                      style: const TextStyle(
                        backgroundColor: Colors.white24,
                        color: Colors.black,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
