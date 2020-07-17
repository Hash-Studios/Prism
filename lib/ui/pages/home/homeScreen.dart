import 'package:Prism/data/prism/provider/prismProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/widgets/home/gridLoader.dart';
import 'package:Prism/ui/widgets/popup/changelogPopUp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/ui/widgets/popup/updatePopUp.dart';
import 'package:Prism/global/globals.dart' as globals;

class HomeScreen extends StatefulWidget {
  HomeScreen({
    Key key,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  //Check for update if available
  String currentAppVersion = "2.4.3";
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
    navStack.removeLast();
    print(navStack);
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
    super.initState();
  }

  void _updateToken() {
    FirebaseMessaging f = new FirebaseMessaging();
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
    var newApp = main.prefs.getBool("newApp");
    if (newApp == null) {
      showChangelog(context, () {
        setState(() {
          isNew = false;
        });
      });
      main.prefs.setBool("newApp", false);
    } else {
      main.prefs.setBool("newApp", false);
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
    // if (isNew) {
    //   Future.delayed(Duration(seconds: 0))
    //       .then((value) => showChangelogCheck(context));
    // }
    initDynamicLinks(context);
    return WillPopScope(
      onWillPop: onWillPop,
      child: GridLoader(
        future:
            Provider.of<PrismProvider>(context, listen: false).getPrismWalls(),
        provider: "Prism",
      ),
    );
  }
}
