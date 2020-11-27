import 'package:Prism/payments/components.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/object_wrappers.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/global/globals.dart' as globals;

class PurchaseScreenTry extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 60), curve: Curves.linear);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [
              config.Colors().mainAccentColor(1),
              Theme.of(context).primaryColor
            ],
            stops: [
              0.1,
              0.6
            ]),
      ),
      child: SafeArea(
        child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SingleChildScrollView(
              child: Container(
                height: MediaQuery.of(context).size.height -
                    (globals.notchSize ?? 24),
                child: Stack(
                  children: [
                    Container(
                      height: 300,
                      width: MediaQuery.of(context).size.width,
                      child: CachedNetworkImage(
                        imageUrl:
                            "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fprism%20mock.png?alt=media&token=a86d1386-dbb5-493f-8399-ff0160b1a86a",
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
                              width: 20,
                            ),
                            SizedBox(
                                width: 40,
                                height: 40,
                                child: Image.asset("assets/images/prism.png")),
                            const SizedBox(
                              width: 10,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Premium",
                                style: Theme.of(context)
                                    .textTheme
                                    .headline2
                                    .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
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
                              width: 20,
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Unlock everything",
                                style: Theme.of(context)
                                    .textTheme
                                    .headline5
                                    .copyWith(color: const Color(0xFFE57697)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: 58,
                          child: ListView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            children: const [
                              SizedBox(
                                width: 20,
                              ),
                              FeatureChip(
                                  icon: JamIcons.picture,
                                  text: "Exclusive wallpapers"),
                              FeatureChip(
                                  icon: JamIcons.instant_picture,
                                  text: "No restrictions on setups"),
                              FeatureChip(
                                  icon: JamIcons.trophy,
                                  text: "Premium only giveaways"),
                              FeatureChip(
                                  icon: JamIcons.filter,
                                  text: "Apply filters on walls"),
                              FeatureChip(
                                  icon: JamIcons.user,
                                  text: "Unique PRO badge on your profile"),
                              FeatureChip(
                                  icon: JamIcons.upload,
                                  text: "Faster upload reviews"),
                              FeatureChip(
                                  icon: JamIcons.stop_sign, text: "Remove Ads"),
                              FeatureChip(
                                  icon: JamIcons.coffee_cup,
                                  text:
                                      "Support development, and content growth"),
                            ],
                          ),
                        ),
                        const Spacer(
                          flex: 1,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: Provider.of<ThemeModel>(context)
                                                .currentTheme ==
                                            kDarkTheme2
                                        ? Theme.of(context).accentColor
                                        : config.Colors().mainAccentColor(1),
                                    width: 4),
                                color: const Color(0x15ffffff),
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lifetime',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline3
                                          .copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      'SALE',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline6
                                          .copyWith(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                                const Spacer(flex: 4),
                                Text(
                                  'Price',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headline3
                                      .copyWith(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: GestureDetector(
                            // ignore: void_checks
                            onTap: () async {
                              // try {
                              //   debugPrint('now trying to purchase');
                              //   _purchaserInfo =
                              //       await Purchases.purchasePackage(widget.package);
                              //   debugPrint('purchase completed');

                              //   appData.isPro = _purchaserInfo
                              //       .entitlements.all["prism_premium"].isActive;
                              //   main.prefs.put('premium', appData.isPro);
                              //   debugPrint('is user pro? ${appData.isPro}');

                              //   if (appData.isPro) {
                              //     toasts.codeSend("You are now a premium member.");
                              //     main.RestartWidget.restartApp(context);
                              //   } else {
                              //     toasts
                              //         .error("There was an error, please try again later.");
                              //   }
                              // } on PlatformException catch (e) {
                              //   debugPrint('----xx-----');
                              //   final errorCode = PurchasesErrorHelper.getErrorCode(e);
                              //   if (errorCode ==
                              //       PurchasesErrorCode.purchaseCancelledError) {
                              //     toasts.error("User cancelled purchase.");
                              //   } else if (errorCode ==
                              //       PurchasesErrorCode.purchaseNotAllowedError) {
                              //     toasts.error("User not allowed to purchase.");
                              //   } else {
                              //     toasts.error(e.toString());
                              //   }
                              // }
                              // return UpgradeScreen();
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              decoration: BoxDecoration(
                                  color: Provider.of<ThemeModel>(context)
                                              .currentTheme ==
                                          kDarkTheme2
                                      ? Theme.of(context).accentColor
                                      : config.Colors().mainAccentColor(1),
                                  borderRadius: BorderRadius.circular(500)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Purchase',
                                style: Theme.of(context)
                                    .textTheme
                                    .headline3
                                    .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: GestureDetector(
                            // ignore: void_checks
                            onTap: () async {
                              try {
                                debugPrint('now trying to restore');
                                final PurchaserInfo restoredInfo =
                                    await Purchases.restoreTransactions();
                                debugPrint('restore completed');
                                debugPrint(restoredInfo.toString());

                                appData.isPro = restoredInfo
                                    .entitlements.all["prism_premium"].isActive;

                                debugPrint('is user pro? ${appData.isPro}');

                                if (appData.isPro) {
                                  main.prefs.put('premium', appData.isPro);
                                  toasts.codeSend(
                                      "You are now a premium member.");
                                  main.RestartWidget.restartApp(context);
                                } else {
                                  toasts.error(
                                      "There was an error. Please try again later.");
                                }
                              } on PlatformException catch (e) {
                                debugPrint('----xx-----');
                                final errorCode =
                                    PurchasesErrorHelper.getErrorCode(e);
                                if (errorCode ==
                                    PurchasesErrorCode.purchaseCancelledError) {
                                  toasts.error("User cancelled purchase.");
                                } else if (errorCode ==
                                    PurchasesErrorCode
                                        .purchaseNotAllowedError) {
                                  toasts.error("User not allowed to purchase.");
                                } else {
                                  toasts.error(e.toString());
                                }
                              }
                              return UpgradeScreen();
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(500)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12.0),
                              child: Text(
                                'Restore',
                                style: Theme.of(context)
                                    .textTheme
                                    .headline3
                                    .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          child: Text(
                            "By purchasing this product you will be able to access the Prism premium functionalities on all the devices logged into your Google account.",
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headline6
                                .copyWith(fontSize: 12, color: Colors.white),
                          ),
                        ),
                        const Spacer(
                          flex: 1,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ),
    );
  }
}

class FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const FeatureChip({
    @required this.icon,
    @required this.text,
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
      child: ActionChip(
          labelPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          avatar: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8.0),
            child: Icon(
              icon,
              size: 22,
              color: Colors.white,
            ),
          ),
          label: Text(
            " $text",
            style: Theme.of(context)
                .textTheme
                .headline5
                .copyWith(color: Colors.white),
          ),
          onPressed: () {}),
    );
  }
}
