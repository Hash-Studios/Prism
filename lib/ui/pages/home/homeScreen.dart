import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/widgets/home/pexelsGrid.dart';
import 'package:Prism/ui/widgets/home/wallhavenGrid.dart';
import 'package:Prism/ui/widgets/home/wallpaperGrid.dart';
import 'package:Prism/ui/widgets/popup/changelogPopUp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/ui/widgets/popup/updatePopUp.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:provider/provider.dart';

Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) {
  if (message.containsKey('data')) {
    // Handle data message
    final dynamic data = message['data'];
    print(data);
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    final dynamic notification = message['notification'];
    print(notification);
  }

  // Or do other work.
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
  final databaseReference = Firestore.instance;

  Future<void> _checkUpdate() async {
    print("checking for update");
    try {
      databaseReference.collection("appConfig").getDocuments().then((value) {
        print("Current App Version :" + currentAppVersion);
        print("Latest Version :" +
            value.documents[0]["currentVersion"].toString());
        setState(() {
          if (currentAppVersion !=
              value.documents[0]["currentVersion"].toString()) {
            setState(() {
              globals.updateAvailable = true;
              globals.versionInfo = {
                "version_number":
                    value.documents[0]["currentVersion"].toString(),
                "version_desc": value.documents[0]["versionDesc"],
              };
            });
          } else {
            setState(() {
              globals.updateAvailable = false;
            });
          }
        });
        globals.updateAvailable
            ? !globals.noNewNotification
                ? showUpdate(context)
                : print("No new notification")
            : print("No update");
      });
    } catch (e) {
      print("Error while checking for updates!");
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
    if (!globals.updateChecked) {
      _checkUpdate();
    }
    isNew = true;
    _updateToken();
    _future = Future.delayed(Duration(seconds: 0)).then((value) =>
        Provider.of<CategorySupplier>(context, listen: false)
            .wallpaperFutureRefresh);
    super.initState();
  }

  void _updateToken() {
    FirebaseMessaging f = new FirebaseMessaging();
    f.requestNotificationPermissions();
    f.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        // _showItemDialog(message);
      },
      onBackgroundMessage: myBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        // _navigateToItemDetail(message);
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
        // _navigateToItemDetail(message);
      },
    );

    f.getToken().then((value) {
      // print(value);
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

  void initDynamicLinks(BuildContext context) async {
    final PendingDynamicLinkData data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    final Uri deepLink = data?.link;

    if (deepLink != null) {
      print("opened while closed altogether via deep link");
      Future.delayed(Duration(seconds: 0))
          .then((value) => Navigator.pushNamed(context, ShareRoute, arguments: [
                deepLink.queryParameters["id"],
                deepLink.queryParameters["provider"],
                deepLink.queryParameters["url"],
                deepLink.queryParameters["thumb"],
              ]));
      print("opened while closed altogether via deep link2345");
    }

    FirebaseDynamicLinks.instance.onLink(
        onSuccess: (PendingDynamicLinkData dynamicLink) async {
      final Uri deepLink = dynamicLink?.link;

      if (deepLink != null) {
        print("opened while bg via deep link1");
        Future.delayed(Duration(seconds: 0)).then(
            (value) => Navigator.pushNamed(context, ShareRoute, arguments: [
                  deepLink.queryParameters["id"],
                  deepLink.queryParameters["provider"],
                  deepLink.queryParameters["url"],
                  deepLink.queryParameters["thumb"],
                ]));
        print("opened while bg via deep link2345");
      }
    }, onError: (OnLinkErrorException e) async {
      print('onLinkError');
      print(e.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    initDynamicLinks(context);
    return WillPopScope(
      onWillPop: onWillPop,
      child: new FutureBuilder<List>(
        future: _future, // async work
        builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return new Text('Loading....');
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
