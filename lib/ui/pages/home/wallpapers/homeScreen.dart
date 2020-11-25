import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/home/wallpapers/pexelsGrid.dart';
import 'package:Prism/ui/widgets/home/wallpapers/wallhavenGrid.dart';
import 'package:Prism/ui/widgets/home/wallpapers/wallpaperGrid.dart';
import 'package:Prism/ui/widgets/popup/changelogPopUp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

final FirebaseMessaging f = FirebaseMessaging();

Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) {
  writeNotifications(message);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    Key key,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List> _future;

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    debugPrint("Bye! Have a good day!");
    return true;
  }

  bool isNew;
  @override
  void initState() {
    super.initState();
    isNew = true;
    _updateToken();
    _future = Future.delayed(const Duration()).then((value) =>
        Provider.of<CategorySupplier>(context, listen: false)
            .wallpaperFutureRefresh);
  }

  void _updateToken() {
    f.requestNotificationPermissions();
    f.configure(
      onMessage: (Map<String, dynamic> message) async {
        writeNotifications(message);
      },
      onBackgroundMessage: myBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) async {
        debugPrint("onLaunch: $message");
        writeNotifications(message);
      },
      onResume: (Map<String, dynamic> message) async {
        debugPrint("onResume: $message");
        writeNotifications(message);
      },
    );

    f.getToken().then((value) {
      debugPrint("FCM Token $value");
      Firestore.instance.collection('tokens').document(value).setData({
        "devtoken": value.toString(),
        "createdAt": DateTime.now().toIso8601String()
      }).then((value) {});
    }).catchError((onError) {
      debugPrint(onError.toString());
    });
  }

  void showChangelogCheck(BuildContext context) {
    final newDevice = main.prefs.get("newDevice");
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
    if (isNew) {
      Future.delayed(const Duration())
          .then((value) => showChangelogCheck(context));
    }
    return WillPopScope(
      onWillPop: onWillPop,
      child: FutureBuilder<List>(
        future: _future, // async work
        builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Center(child: Loader());
            case ConnectionState.none:
              return Center(child: Loader());
            default:
              if (snapshot.hasError) {
                return RefreshIndicator(
                    onRefresh: () async {
                      // ignore: unnecessary_statements
                      _future;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const <Widget>[
                        Spacer(),
                        Center(child: Text("Can't connect to the Servers!")),
                        Spacer(),
                      ],
                    ));
              } else {
                if (Provider.of<CategorySupplier>(context)
                        .selectedChoice
                        .provider ==
                    "WallHaven") {
                  return WallHavenGrid(
                      provider: Provider.of<CategorySupplier>(context)
                          .selectedChoice
                          .provider);
                } else if (Provider.of<CategorySupplier>(context)
                        .selectedChoice
                        .provider ==
                    "Pexels") {
                  return PexelsGrid(
                      provider: Provider.of<CategorySupplier>(context)
                          .selectedChoice
                          .provider);
                } else {
                  return WallpaperGrid(
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
