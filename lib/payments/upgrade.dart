import 'dart:async';
import 'package:Prism/gitkey.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:purchases_flutter/object_wrappers.dart';
import 'package:Prism/payments/components.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';

PurchaserInfo? _purchaserInfo;

Future<void> checkPremium() async {
  appData.isPro = false;

  await Purchases.setup(apiKey, appUserId: globals.prismUser.id);

  PurchaserInfo purchaserInfo;
  try {
    purchaserInfo = await Purchases.getPurchaserInfo();
    if (purchaserInfo.entitlements.all['prism_premium'] != null) {
      appData.isPro = purchaserInfo.entitlements.all['prism_premium']!.isActive;
    } else {
      appData.isPro = false;
    }
  } on PlatformException catch (e) {
    logger.d(e.toString());
  }

  globals.prismUser.premium = appData.isPro!;
  main.prefs.put(main.userHiveKey, globals.prismUser);
  logger.d('#### is user pro? ${appData.isPro}');
}

class UpgradeScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  Offerings? _offerings;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    fetchData();
  }

  Future<void> initPlatformState() async {
    appData.isPro = false;

    await Purchases.setDebugLogsEnabled(true);
    await Purchases.setup(apiKey, appUserId: globals.prismUser.id);

    PurchaserInfo purchaserInfo;
    try {
      purchaserInfo = await Purchases.getPurchaserInfo();
      logger.d(purchaserInfo.toString());
      if (purchaserInfo.entitlements.all['prism_premium'] != null) {
        appData.isPro =
            purchaserInfo.entitlements.all['prism_premium']!.isActive;
      } else {
        appData.isPro = false;
      }
    } on PlatformException catch (e) {
      logger.d(e.toString());
    }

    logger.d('#### is user pro? ${appData.isPro}');
    setState(() {});
  }

  Future<void> fetchData() async {
    PurchaserInfo? purchaserInfo;
    try {
      purchaserInfo = await Purchases.getPurchaserInfo();
    } on PlatformException catch (e) {
      logger.d(e.toString());
    }

    Offerings? offerings;
    try {
      offerings = await Purchases.getOfferings();
    } on PlatformException catch (e) {
      logger.d(e.toString());
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
            child: Loader(),
          ),
        ),
      );
    } else {
      if (_purchaserInfo!.entitlements.all.isNotEmpty &&
          _purchaserInfo!.entitlements.all['prism_premium'] != null) {
        appData.isPro =
            _purchaserInfo!.entitlements.all['prism_premium']!.isActive;
      } else {
        appData.isPro = false;
      }
      if (appData.isPro!) {
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
  final Offerings? offerings;

  const UpsellScreen({Key? key, required this.offerings}) : super(key: key);

  @override
  _UpsellScreenState createState() => _UpsellScreenState();
}

Future<bool> onWillPop() async {
  if (navStack.length > 1) navStack.removeLast();
  logger.d(navStack.toString());
  return true;
}

class _UpsellScreenState extends State<UpsellScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Widget> features = [
    const SizedBox(
      width: 30,
    ),
    const FeatureChip(icon: JamIcons.picture, text: "Exclusive wallpapers"),
    const FeatureChip(icon: JamIcons.picture, text: "Upload unlimited walls"),
    const FeatureChip(
        icon: JamIcons.instant_picture, text: "No restrictions on setups"),
    const FeatureChip(icon: JamIcons.trophy, text: "Premium only giveaways"),
    const FeatureChip(icon: JamIcons.filter, text: "Apply filters on walls"),
    const FeatureChip(
        icon: JamIcons.user, text: "Unique PRO badge on your profile"),
    const FeatureChip(icon: JamIcons.upload, text: "Faster upload reviews"),
    const FeatureChip(icon: JamIcons.stop_sign, text: "Remove Ads"),
    const FeatureChip(
        icon: JamIcons.coffee_cup,
        text: "Support development, and content growth"),
  ];

  void _scrollToBottom() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 6000), curve: Curves.linear);
  }

  @override
  void initState() {
    for (var i = 0; i < 100; i++) {
      features.addAll(const [
        FeatureChip(icon: JamIcons.picture, text: "Exclusive wallpapers"),
        FeatureChip(icon: JamIcons.picture, text: "Upload unlimited walls"),
        FeatureChip(
            icon: JamIcons.instant_picture, text: "No restrictions on setups"),
        FeatureChip(icon: JamIcons.trophy, text: "Premium only giveaways"),
        FeatureChip(icon: JamIcons.filter, text: "Apply filters on walls"),
        FeatureChip(
            icon: JamIcons.user, text: "Unique PRO badge on your profile"),
        FeatureChip(icon: JamIcons.upload, text: "Faster upload reviews"),
        FeatureChip(icon: JamIcons.stop_sign, text: "Remove Ads"),
        FeatureChip(
            icon: JamIcons.coffee_cup,
            text: "Support development, and content growth"),
      ]);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance!.addPostFrameCallback((_) => _scrollToBottom());
    if (widget.offerings != null) {
      final offering = widget.offerings!.current;
      if (offering != null) {
        final lifetime = offering.lifetime;
        if (lifetime != null) {
          return WillPopScope(
            onWillPop: onWillPop,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).errorColor,
                      Theme.of(context).primaryColor
                    ],
                    stops: const [
                      0.1,
                      0.6
                    ]),
              ),
              child: SafeArea(
                child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: SingleChildScrollView(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height -
                            (globals.notchSize ?? 24),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 420,
                              width: MediaQuery.of(context).size.width,
                              child: CachedNetworkImage(
                                imageUrl:
                                    "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fprism%20mock.png?alt=media&token=a86d1386-dbb5-493f-8399-ff0160b1a86a",
                                fit: BoxFit.fitHeight,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Spacer(
                                  flex: 12,
                                ),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 30,
                                    ),
                                    SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Image.asset(
                                            "assets/images/prism.png")),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.8,
                                      child: Text(
                                        "Premium",
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline2!
                                            .copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .accentColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 30,
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.8,
                                      child: Text(
                                        "Unlock everything",
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline5!
                                            .copyWith(
                                                color: const Color(0xFFE57697)),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  margin:
                                      const EdgeInsets.fromLTRB(0, 10, 0, 0),
                                  width: MediaQuery.of(context).size.width,
                                  height: 58,
                                  child: GestureDetector(
                                    onTap: _scrollToBottom,
                                    child: ListView(
                                      controller: _scrollController,
                                      scrollDirection: Axis.horizontal,
                                      children: features,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.8,
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Theme.of(context).errorColor ==
                                                  Colors.black
                                              ? Theme.of(context).accentColor
                                              : Theme.of(context).errorColor,
                                          width: 4),
                                      color: const Color(0x15ffffff),
                                      borderRadius: BorderRadius.circular(10)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Lifetime',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline3!
                                                .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .accentColor),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (lifetime.product.title
                                              .contains("SALE"))
                                            Text(
                                              'SALE',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headline6!
                                                  .copyWith(color: Colors.red),
                                              textAlign: TextAlign.center,
                                            )
                                          else
                                            Container(),
                                        ],
                                      ),
                                      const Spacer(flex: 4),
                                      Text(
                                        lifetime.product.priceString,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline3!
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .accentColor),
                                        textAlign: TextAlign.center,
                                      ),
                                      const Spacer(),
                                    ],
                                  ),
                                ),
                                PurchaseButton(package: lifetime),
                                Padding(
                                  padding: const EdgeInsets.only(top: 18.0),
                                  child: GestureDetector(
                                    // ignore: void_checks
                                    onTap: () async {
                                      try {
                                        logger.d('now trying to restore');
                                        final PurchaserInfo restoredInfo =
                                            await Purchases
                                                .restoreTransactions();
                                        logger.d('restore completed');
                                        logger.d(restoredInfo.toString());

                                        appData.isPro = restoredInfo
                                            .entitlements
                                            .all["prism_premium"]!
                                            .isActive;

                                        logger
                                            .d('is user pro? ${appData.isPro}');

                                        if (appData.isPro!) {
                                          globals.prismUser.premium =
                                              appData.isPro!;
                                          main.prefs.put(main.userHiveKey,
                                              globals.prismUser);
                                          toasts.codeSend(
                                              "You are now a premium member.");
                                          main.RestartWidget.restartApp(
                                              context);
                                        } else {
                                          toasts.error(
                                              "There was an error. Please try again later.");
                                        }
                                      } on PlatformException catch (e) {
                                        logger.d('----xx-----');
                                        final errorCode =
                                            PurchasesErrorHelper.getErrorCode(
                                                e);
                                        if (errorCode ==
                                            PurchasesErrorCode
                                                .purchaseCancelledError) {
                                          toasts.error(
                                              "User cancelled purchase.");
                                        } else if (errorCode ==
                                            PurchasesErrorCode
                                                .purchaseNotAllowedError) {
                                          toasts.error(
                                              "User not allowed to purchase.");
                                        } else {
                                          toasts.error(e.toString());
                                        }
                                      }
                                      // return UpgradeScreen();
                                    },
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.8,
                                      decoration: BoxDecoration(
                                          color: Theme.of(context).errorColor ==
                                                  Colors.black
                                              ? Theme.of(context)
                                                  .accentColor
                                                  .withOpacity(0.1)
                                              : Theme.of(context).accentColor,
                                          borderRadius:
                                              BorderRadius.circular(500)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12.0),
                                      child: Text(
                                        'Restore',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline3!
                                            .copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                            .errorColor ==
                                                        Colors.black
                                                    ? Colors.white
                                                    : Theme.of(context)
                                                        .primaryColor),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.8,
                                  child: Text(
                                    "By purchasing this product you will be able to access the Prism premium functionalities on all the devices logged into your Google account.",
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline6!
                                        .copyWith(
                                            fontSize: 12,
                                            color:
                                                Theme.of(context).accentColor),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
              ),
            ),
          );
        }
      }
    } else {
      return WillPopScope(
        onWillPop: onWillPop,
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: Center(
            child: Loader(),
          ),
        ),
      );
    }
    return Container();
  }
}

class PurchaseButton extends StatefulWidget {
  final Package package;

  const PurchaseButton({Key? key, required this.package}) : super(key: key);

  @override
  _PurchaseButtonState createState() => _PurchaseButtonState();
}

class _PurchaseButtonState extends State<PurchaseButton> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18.0),
      child: GestureDetector(
        // ignore: void_checks
        onTap: () async {
          try {
            logger.d('now trying to purchase');
            _purchaserInfo = await Purchases.purchasePackage(widget.package);
            logger.d('purchase completed');

            appData.isPro =
                _purchaserInfo!.entitlements.all["prism_premium"]!.isActive;
            globals.prismUser.premium = appData.isPro!;
            main.prefs.put(main.userHiveKey, globals.prismUser);
            logger.d('is user pro? ${appData.isPro}');

            if (appData.isPro!) {
              toasts.codeSend("You are now a premium member.");
              main.RestartWidget.restartApp(context);
            } else {
              toasts.error("There was an error, please try again later.");
            }
          } on PlatformException catch (e) {
            logger.d('----xx-----');
            final errorCode = PurchasesErrorHelper.getErrorCode(e);
            if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
              toasts.error("User cancelled purchase.");
            } else if (errorCode ==
                PurchasesErrorCode.purchaseNotAllowedError) {
              toasts.error("User not allowed to purchase.");
            } else {
              toasts.error(e.toString());
            }
          }
          // return UpgradeScreen();
        },
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          decoration: BoxDecoration(
              color: Theme.of(context).errorColor == Colors.black
                  ? Theme.of(context).accentColor
                  : Theme.of(context).errorColor,
              borderRadius: BorderRadius.circular(500)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Purchase',
            style: Theme.of(context).textTheme.headline3!.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor),
            textAlign: TextAlign.center,
          ),
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
                    color: Theme.of(context).errorColor,
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

class FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const FeatureChip({
    required this.icon,
    required this.text,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
      child: ActionChip(
          backgroundColor: Theme.of(context).errorColor.withOpacity(0.3),
          labelPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          avatar: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8.0),
            child: Icon(
              icon,
              size: 22,
              color: Theme.of(context).accentColor,
            ),
          ),
          label: Text(
            " $text",
            style: Theme.of(context)
                .textTheme
                .headline5!
                .copyWith(color: Theme.of(context).accentColor),
          ),
          onPressed: () {}),
    );
  }
}
