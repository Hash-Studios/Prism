import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'components.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;

PurchaserInfo _purchaserInfo;

Future<void> initPlatformState() async {
  appData.isPro = false;

  await Purchases.setDebugLogsEnabled(true);
  await Purchases.setup(apiKey, appUserId: main.prefs.get('id'));

  PurchaserInfo purchaserInfo;
  try {
    purchaserInfo = await Purchases.getPurchaserInfo();
    print(purchaserInfo.toString());
    if (purchaserInfo.entitlements.all['prism_premium'] != null) {
      appData.isPro = purchaserInfo.entitlements.all['prism_premium'].isActive;
    } else {
      appData.isPro = false;
    }
  } on PlatformException catch (e) {
    print(e);
  }

  print('#### is user pro? ${appData.isPro}');
}

Future<void> checkPremium() async {
  appData.isPro = false;

  await Purchases.setup(apiKey, appUserId: main.prefs.get('id'));

  PurchaserInfo purchaserInfo;
  try {
    purchaserInfo = await Purchases.getPurchaserInfo();
    // print(purchaserInfo.toString());
    if (purchaserInfo.entitlements.all['prism_premium'] != null) {
      appData.isPro = purchaserInfo.entitlements.all['prism_premium'].isActive;
    } else {
      appData.isPro = false;
    }
  } on PlatformException catch (e) {
    print(e);
  }

  main.prefs.put('premium', appData.isPro);
  print('#### is user pro? ${appData.isPro}');
}

class UpgradeScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  Offerings _offerings;

  @override
  void initState() {
    super.initState();
    fetchData();
    initPlatformState();
  }

  Future<void> fetchData() async {
    PurchaserInfo purchaserInfo;
    try {
      purchaserInfo = await Purchases.getPurchaserInfo();
    } on PlatformException catch (e) {
      print(e);
    }

    Offerings offerings;
    try {
      offerings = await Purchases.getOfferings();
    } on PlatformException catch (e) {
      print(e);
    }
    if (!mounted) return;

    setState(() {
      _purchaserInfo = purchaserInfo;
      _offerings = offerings;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_purchaserInfo == null) {
      return WillPopScope(
        onWillPop: onWillPop,
        child: Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            body: Center(
                child: Text(
              "Loading...",
            ))),
      );
    } else {
      if (_purchaserInfo.entitlements.all.isNotEmpty &&
          _purchaserInfo.entitlements.all['prism_premium'] != null) {
        appData.isPro =
            _purchaserInfo.entitlements.all['prism_premium'].isActive;
      } else {
        appData.isPro = false;
      }
      if (appData.isPro) {
        return ProScreen();
      } else {
        return UpsellScreen(
          offerings: _offerings,
        );
      }
    }
  }
}

class UpsellScreen extends StatefulWidget {
  final Offerings offerings;

  UpsellScreen({Key key, @required this.offerings}) : super(key: key);

  @override
  _UpsellScreenState createState() => _UpsellScreenState();
}

Future<bool> onWillPop() async {
  if (navStack.length > 1) navStack.removeLast();
  print(navStack);
  return true;
}

class _UpsellScreenState extends State<UpsellScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.offerings != null) {
      final offering = widget.offerings.current;
      if (offering != null) {
        final lifetime = offering.lifetime;
        if (lifetime != null) {
          return WillPopScope(
            onWillPop: onWillPop,
            child: Scaffold(
                backgroundColor: Theme.of(context).primaryColor,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: Text("Purchase"),
                  leading: IconButton(
                    icon: Icon(JamIcons.close),
                    onPressed: () {
                      if (navStack.length > 1) navStack.removeLast();
                      print(navStack);
                      Navigator.pop(context);
                    },
                  ),
                ),
                body: Container(
                    height: MediaQuery.of(context).size.height,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          height: 200,
                          width: MediaQuery.of(context).size.width,
                          decoration:
                              BoxDecoration(color: Theme.of(context).hintColor),
                          child: FlareActor(
                            "assets/animations/Premium.flr",
                            isPaused: false,
                            alignment: Alignment.center,
                            animation: "premium",
                          ),
                        ),
                        Spacer(
                          flex: 4,
                        ),
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                              child: Text(
                                'PREMIUM UNLOCKS:',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Theme.of(context).accentColor),
                              ),
                            ),
                          ],
                        ),
                        Spacer(
                          flex: 1,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            Icon(
                              JamIcons.instant_picture,
                              size: 22,
                              color: Color(0xFFE57697),
                            ),
                            SizedBox(
                              width: 20,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Get more exclusive Home Screen setups!",
                                style: Theme.of(context)
                                    .textTheme
                                    .headline6
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            Icon(
                              JamIcons.filter,
                              size: 22,
                              color: Color(0xFFE57697),
                            ),
                            SizedBox(
                              width: 20,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Directly set upto 5 variants of each wallpaper!",
                                style: Theme.of(context)
                                    .textTheme
                                    .headline6
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            Icon(
                              JamIcons.user,
                              size: 22,
                              color: Color(0xFFE57697),
                            ),
                            SizedBox(
                              width: 20,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Get PRO badge on your profile.",
                                style: Theme.of(context)
                                    .textTheme
                                    .headline6
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            Icon(
                              JamIcons.clock,
                              size: 22,
                              color: Color(0xFFE57697),
                            ),
                            SizedBox(
                              width: 20,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Get your uploads reviewed instantly.",
                                style: Theme.of(context)
                                    .textTheme
                                    .headline6
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            Icon(
                              JamIcons.download,
                              size: 22,
                              color: Color(0xFFE57697),
                            ),
                            SizedBox(
                              width: 20,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Download any wallpaper instantly.",
                                style: Theme.of(context)
                                    .textTheme
                                    .headline6
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                            ),
                            Icon(
                              JamIcons.coffee,
                              size: 22,
                              color: Color(0xFFE57697),
                            ),
                            SizedBox(
                              width: 20,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Prism is completely free of disturbing ads and therfore this is the only way to support the development of the app.",
                                style: Theme.of(context)
                                    .textTheme
                                    .headline6
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              ),
                            ),
                          ],
                        ),
                        Spacer(
                          flex: 4,
                        ),
                        PurchaseButton(package: lifetime),
                        Spacer(
                          flex: 2,
                        ),
                        FlatButton(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .accentColor
                                    .withOpacity(0.75),
                                borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.all(10.0),
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: Text(
                                'Restore Purchases',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).primaryColor),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              print('now trying to restore');
                              PurchaserInfo restoredInfo =
                                  await Purchases.restoreTransactions();
                              print('restore completed');
                              print(restoredInfo.toString());

                              appData.isPro = restoredInfo
                                  .entitlements.all["prism_premium"].isActive;

                              print('is user pro? ${appData.isPro}');

                              if (appData.isPro) {
                                main.prefs.put('premium', appData.isPro);
                                toasts
                                    .codeSend("You are now a premium member.");
                                main.RestartWidget.restartApp(context);
                              } else {
                                toasts.error(
                                    "There was an error. Please try again later.");
                              }
                            } on PlatformException catch (e) {
                              print('----xx-----');
                              var errorCode =
                                  PurchasesErrorHelper.getErrorCode(e);
                              if (errorCode ==
                                  PurchasesErrorCode.purchaseCancelledError) {
                                toasts.error("User cancelled purchase.");
                              } else if (errorCode ==
                                  PurchasesErrorCode.purchaseNotAllowedError) {
                                toasts.error("User not allowed to purchase.");
                              } else {
                                toasts.error(e.toString());
                              }
                            }
                            return UpgradeScreen();
                          },
                        ),
                        Spacer(
                          flex: 1,
                        ),
                      ],
                    ))),
          );
        }
      }
    }
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text("Purchase"),
            leading: IconButton(
              icon: Icon(JamIcons.close),
              onPressed: () {
                if (navStack.length > 1) navStack.removeLast();
                print(navStack);
                Navigator.pop(context);
              },
            ),
          ),
          body: Center(
              child: Text(
            "Loading...",
          ))),
    );
  }
}

class PurchaseButton extends StatefulWidget {
  final Package package;

  PurchaseButton({Key key, @required this.package}) : super(key: key);

  @override
  _PurchaseButtonState createState() => _PurchaseButtonState();
}

class _PurchaseButtonState extends State<PurchaseButton> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 30.0, right: 30.0),
      child: Container(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 18.0),
              child: FlatButton(
                onPressed: () async {
                  try {
                    print('now trying to purchase');
                    _purchaserInfo =
                        await Purchases.purchasePackage(widget.package);
                    print('purchase completed');

                    appData.isPro = _purchaserInfo
                        .entitlements.all["prism_premium"].isActive;
                    main.prefs.put('premium', appData.isPro);
                    print('is user pro? ${appData.isPro}');

                    if (appData.isPro) {
                      toasts.codeSend("You are now a premium member.");
                      main.RestartWidget.restartApp(context);
                    } else {
                      toasts
                          .error("There was an error, please try again later.");
                    }
                  } on PlatformException catch (e) {
                    print('----xx-----');
                    var errorCode = PurchasesErrorHelper.getErrorCode(e);
                    if (errorCode ==
                        PurchasesErrorCode.purchaseCancelledError) {
                      toasts.error("User cancelled purchase.");
                    } else if (errorCode ==
                        PurchasesErrorCode.purchaseNotAllowedError) {
                      toasts.error("User not allowed to purchase.");
                    } else {
                      toasts.error(e.toString());
                    }
                  }
                  return UpgradeScreen();
                },
                padding: const EdgeInsets.all(0.0),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  decoration: BoxDecoration(
                      color: Color(0xFFE57697),
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      Container(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: Text(
                          'Buy ${widget.package.product.title}',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.24,
                        child: Text(
                          '${widget.package.product.priceString}',
                          style: TextStyle(fontSize: 22),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 18.0),
              child: Text(
                '${widget.package.product.description}',
                textAlign: TextAlign.center,
                style: kSendButtonTextStyle.copyWith(
                    fontSize: 13, fontWeight: FontWeight.w400),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class ProScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Icon(
                    Icons.star,
                    color: Color(0xFFE57697),
                    size: 44.0,
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Text(
                      "You are a Prism Premium user.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )),
                Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Text(
                      "You can use the app in all its functionality.\n\nPlease contact us at hash.studios.inc@gmail.com if you have any problem.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ).copyWith(fontSize: 14),
                    )),
              ],
            ),
          )),
    );
  }
}
