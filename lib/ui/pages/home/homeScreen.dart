import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/routes/router.dart';
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
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

final FirebaseMessaging f = new FirebaseMessaging();

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
      url: message['data']['url'] ?? ""));
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
    isNew = true;
    _updateToken();
    _future = Future.delayed(Duration(seconds: 0)).then((value) =>
        Provider.of<CategorySupplier>(context, listen: false)
            .wallpaperFutureRefresh);
  }

  void _updateToken() {
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
    var newDevice = main.prefs.get("newDevice");
    if (newDevice == null) {
      showChangelog(context, () {
        setState(() {
          isNew = false;
        });
      });
      main.prefs.put("newDevice", false);
    } else {
      main.prefs.put("newDevice", false);
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
                return RefreshIndicator(
                    onRefresh: () async {
                      _future;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Spacer(),
                        Center(
                            child: new Text("Can't connect to the Servers!")),
                        Spacer(),
                      ],
                    ));
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
