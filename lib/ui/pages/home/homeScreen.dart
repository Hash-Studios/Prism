import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/pages/home/splashScreen.dart';
import 'package:Prism/ui/widgets/home/loading.dart';
import 'package:Prism/ui/widgets/home/pexelsGrid.dart';
import 'package:Prism/ui/widgets/home/wallhavenGrid.dart';
import 'package:Prism/ui/widgets/home/wallpaperGrid.dart';
import 'package:Prism/ui/widgets/popup/changelogPopUp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/notifications/model/notificationModel.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/ui/widgets/popup/updatePopUp.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

void writeNotifications(Map<String, dynamic> message) {
  Box<List> box = Hive.box('notifications');
  var notifications = box.get('notifications');
  if (notifications == null) {
    notifications = [];
  }
  notifications.add(NotifData(
    title: message['notification']['title'] ?? "Notification",
    desc: message['notification']['body'] ?? "",
    imageUrl: message['data']['imageUrl'] ??
        "https://thelifedesigncourse.com/wp-content/uploads/2019/05/orange-waves-background-fluid-gradient-vector-21996148.jpg",
    pageName: message['data']['pageName'],
    arguments: message['data']['arguments'] ?? [],
  ));
  box.put('notifications', notifications);
}

Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) {
  writeNotifications(message);
}

class HomeScreen extends StatefulWidget {
  HomeScreen({
    Key key,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List> _future;
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
          globals.updateAvailable
              ? !globals.noNewNotification
                  ? Future.delayed(Duration(seconds: 0))
                      .whenComplete(() => {showUpdate(context)})
                  : print("No new notification")
              : print("No update");
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

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    print("Bye! Have a good day!");
    return true;
  }

  bool isNew;
  @override
  void initState() {
    super.initState();
    if (!globals.updateChecked) {
      _checkUpdate();
    }
    isNew = true;
    _updateToken();
    _future = Future.delayed(Duration(seconds: 0)).then((value) =>
        Provider.of<CategorySupplier>(context, listen: false)
            .wallpaperFutureRefresh);
  }

  void _updateToken() {
    FirebaseMessaging f = new FirebaseMessaging();
    f.requestNotificationPermissions();
    f.configure(
      onMessage: (Map<String, dynamic> message) async {
        // print("onMessage: $message");
        writeNotifications(message);
        // _showItemDialog(message);
      },
      onBackgroundMessage: myBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        writeNotifications(message);
        // _navigateToItemDetail(message);
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
        writeNotifications(message);
        // _navigateToItemDetail(message);
      },
    );

    f.getToken().then((value) {
      print(value);
      Firestore.instance.collection('tokens').document(value).setData({
        "devtoken": value.toString(),
        "createdAt": DateTime.now().toIso8601String()
      }).then((value) {});
    }).catchError((onError) {
      print(onError.toString());
      // Navigator.pop(context);
    });
  }

  void showChangelogCheck(BuildContext context) {
    var newApp = main.prefs.get("newApp");
    if (newApp == null) {
      showChangelog(context, () {
        setState(() {
          isNew = false;
        });
      });
      main.prefs.put("newApp", false);
    } else {
      main.prefs.put("newApp", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: new FutureBuilder<List>(
        future: _future, // async work
        builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return new LoadingCards();
            case ConnectionState.none:
              return new LoadingCards();
            default:
              if (snapshot.hasError)
                return new Text('Error: ${snapshot.error}');
              else {
                if (Provider.of<CategorySupplier>(context)
                        .selectedChoice
                        .provider ==
                    "WallHaven") {
                  return new WallHavenGrid(
                      provider: Provider.of<CategorySupplier>(context)
                          .selectedChoice
                          .provider);
                } else if (Provider.of<CategorySupplier>(context)
                        .selectedChoice
                        .provider ==
                    "Pexels") {
                  return new PexelsGrid(
                      provider: Provider.of<CategorySupplier>(context)
                          .selectedChoice
                          .provider);
                } else {
                  return new WallpaperGrid(
                      provider: Provider.of<CategorySupplier>(context)
                          .selectedChoice
                          .provider);
                }
              }
          }
        },
      ),
    );
  }
}
