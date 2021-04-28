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
import 'package:intl/intl.dart';
import 'package:Prism/global/globals.dart' as globals;

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List? notifications;
  @override
  void initState() {
    final Box<List> box = Hive.box('notifications');
    if (box.get('notifications') == [] || box.get('notifications') == null) {
      notifications = [];
    } else {
      notifications = box.get('notifications');
    }
    notifications = List.from(notifications!.reversed);
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
                tooltip: "Notification Settings",
                icon: const Icon(JamIcons.settings_alt),
                onPressed: () {
                  showModalBottomSheet(
                      isScrollControlled: true,
                      context: context,
                      builder: (context) => NotificationSettingsSheet());
                })
          ],
        ),
        body: Container(
          child: notifications!.isNotEmpty
              ? ListView.builder(
                  itemCount: notifications!.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Dismissible(
                      onDismissed: (DismissDirection direction) {
                        setState(() {
                          notifications!.removeAt(index);
                        });
                        final Box<List?> box = Hive.box('notifications');
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
                          notification: notifications![index] as NotifData),
                    );
                  },
                )
              : Center(
                  child: Text('No new notifications',
                      style: TextStyle(color: Theme.of(context).accentColor))),
        ),
        floatingActionButton: notifications!.isNotEmpty
            ? FloatingActionButton(
                mini: true,
                tooltip: "Clear Notifications",
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
                            final Box<List?> box = Hive.box('notifications');
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
                        color: Theme.of(context).errorColor,
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
  final NotifData? notification;

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
      leading: CircleAvatar(
        backgroundImage: const AssetImage("assets/images/prism.png"),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      backgroundColor: Theme.of(context).primaryColor,
      title: Text(
        notification!.title!,
        style: TextStyle(
            color: Theme.of(context).accentColor,
            fontWeight: FontWeight.w500,
            fontFamily: "Proxima Nova"),
      ),
      subtitle: Text(
        notification!.desc!,
        style: TextStyle(fontSize: 12, color: Theme.of(context).accentColor),
      ),
      children: <Widget>[
        InkWell(
          onTap: () {
            if (notification!.url == "") {
              if (notification!.pageName != null) {
                Navigator.pushNamed(context, notification!.pageName!,
                    arguments: notification!.arguments);
              }
            } else {
              launch(notification!.url!);
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
                      imageUrl: notification!.imageUrl ??
                          "https://w.wallhaven.cc/full/q6/wallhaven-q6mg5d.jpg",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width * 9 / 16,
                  child: CachedNetworkImage(
                    imageUrl: notification!.imageUrl ??
                        "https://w.wallhaven.cc/full/q6/wallhaven-q6mg5d.jpg",
                    fit: BoxFit.contain,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      stringForDatetime(notification!.createdAt!),
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

class NotificationSettingsSheet extends StatefulWidget {
  @override
  _NotificationSettingsSheetState createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  bool? followersSubscriber;
  bool? postsSubscriber;
  bool? inappSubscriber;
  bool? recommendationsSubscriber;
  @override
  void initState() {
    super.initState();
    followersSubscriber =
        main.prefs.get("followersSubscriber", defaultValue: true) as bool?;
    postsSubscriber =
        main.prefs.get("postsSubscriber", defaultValue: true) as bool?;
    inappSubscriber =
        main.prefs.get("inappSubscriber", defaultValue: true) as bool?;
    recommendationsSubscriber = main.prefs
        .get("recommendationsSubscriber", defaultValue: true) as bool?;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height / 2.3 > 380
            ? MediaQuery.of(context).size.height / 2.3
            : 380,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    height: 5,
                    width: 30,
                    decoration: BoxDecoration(
                        color: Theme.of(context).hintColor,
                        borderRadius: BorderRadius.circular(500)),
                  ),
                )
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Notification Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).errorColor == Colors.black
                        ? Colors.grey
                        : Theme.of(context).errorColor,
                  ),
                ),
              ),
            ),
            SwitchListTile(
              activeColor: Theme.of(context).errorColor,
              secondary: const Icon(
                JamIcons.user_plus,
              ),
              value: followersSubscriber!,
              title: Text(
                "Followers",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: const Text(
                "Get notifications for new followers.",
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (bool value) async {
                if (globals.prismUser.loggedIn == true) {
                  main.prefs.put("followersSubscriber", value);
                  setState(() {
                    followersSubscriber = value;
                  });
                  if (value) {
                    home.f.subscribeToTopic(
                        globals.prismUser.email.split("@")[0].toString());
                  } else {
                    home.f.unsubscribeFromTopic(
                        globals.prismUser.email.split("@")[0].toString());
                    main.prefs.put("postsSubscriber", value);
                    setState(() {
                      postsSubscriber = value;
                    });
                    home.f.unsubscribeFromTopic('posts');
                  }
                } else {
                  toasts.error("Please login to change this setting.");
                }
              },
            ),
            SwitchListTile(
              activeColor: Theme.of(context).errorColor,
              secondary: const Icon(
                JamIcons.pictures,
              ),
              value: postsSubscriber!,
              title: Text(
                "Posts",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: const Text(
                "Get notifications for posts from the artists you follow.",
                style: TextStyle(fontSize: 12),
              ),
              onChanged: followersSubscriber!
                  ? (bool value) async {
                      if (globals.prismUser.loggedIn == true) {
                        main.prefs.put("postsSubscriber", value);
                        setState(() {
                          postsSubscriber = value;
                        });
                        if (value) {
                          home.f.subscribeToTopic('posts');
                        } else {
                          home.f.unsubscribeFromTopic('posts');
                        }
                      } else {
                        toasts.error("Please login to change this setting.");
                      }
                    }
                  : null,
            ),
            SwitchListTile(
              activeColor: Theme.of(context).errorColor,
              secondary: const Icon(
                JamIcons.picture,
              ),
              value: inappSubscriber!,
              title: Text(
                "In-App",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: const Text(
                "Get in app notifications for giveaways, contests and reviews.",
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (bool value) async {
                main.prefs.put("inappSubscriber", value);
                setState(() {
                  inappSubscriber = value;
                });
              },
            ),
            SwitchListTile(
              activeColor: Theme.of(context).errorColor,
              secondary: const Icon(JamIcons.lightbulb),
              value: recommendationsSubscriber!,
              title: Text(
                "Recommendations",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: const Text(
                "Get recommendations from Prism.",
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (bool value) async {
                main.prefs.put("recommendationsSubscriber", value);
                setState(() {
                  recommendationsSubscriber = value;
                });
                if (value) {
                  home.f.subscribeToTopic('recommendations');
                } else {
                  home.f.unsubscribeFromTopic('recommendations');
                }
              },
            ),
            const SizedBox(
              height: 24,
            )
          ],
        ),
      ),
    );
  }
}
