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
    print(purchaserInfo.toString());
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
      return Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: Center(
              child: Text(
            "Loading...",
          )));
    } else {
      if (_purchaserInfo.entitlements.all.isNotEmpty &&
          _purchaserInfo.entitlements.all['prism_premium'].isActive != null) {
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

class _UpsellScreenState extends State<UpsellScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.offerings != null) {
      final offering = widget.offerings.current;
      if (offering != null) {
        // final monthly = offering.monthly;
        final lifetime = offering.lifetime;
        if (
            // monthly != null &&
            lifetime != null) {
          return Scaffold(
              backgroundColor: Theme.of(context).primaryColor,
              appBar: AppBar(title: Text("Purchase")),
              body: Container(
                  height: MediaQuery.of(context).size.height,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Container(
                        height: 150,
                        width: MediaQuery.of(context).size.width * .78,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20)),
                            color: Theme.of(context).hintColor),
                        child: FlareActor(
                          "assets/animations/Premium.flr",
                          isPaused: false,
                          alignment: Alignment.center,
                          animation: "premium",
                        ),
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
                      SizedBox(
                        height: 20,
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
                            width: MediaQuery.of(context).size.width * 0.6,
                            child: Text(
                              "The ability to view setups.",
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
                            width: MediaQuery.of(context).size.width * 0.6,
                            child: Text(
                              "Download or set variants of wallpapers.",
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
                            width: MediaQuery.of(context).size.width * 0.6,
                            child: Text(
                              "Get PRO badge in front of your profile.",
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
                            width: MediaQuery.of(context).size.width * 0.6,
                            child: Text(
                              "Get uploads reviewed instantly.",
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
                            width: MediaQuery.of(context).size.width * 0.6,
                            child: Text(
                              "Support development of the app.",
                              style: Theme.of(context)
                                  .textTheme
                                  .headline6
                                  .copyWith(
                                      color: Theme.of(context).accentColor),
                            ),
                          ),
                        ],
                      ),
                      // PurchaseButton(package: monthly),
                      PurchaseButton(package: lifetime),
                      FlatButton(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.5,
                          decoration: BoxDecoration(
                              color: Theme.of(context).accentColor,
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.all(10.0),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.4,
                            child: Text(
                              'Restore Purchases',
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFFE57697)),
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
                              toasts.codeSend("You are now a premium member.");
                              // Alert(
                              //   context: context,
                              //   style: kWelcomeAlertStyle,
                              //   image: Image.asset(
                              //     "assets/images/avatar_demo.png",
                              //     height: 150,
                              //   ),
                              //   title: "Congratulations",
                              //   content: Column(
                              //     children: <Widget>[
                              //       Padding(
                              //         padding: const EdgeInsets.only(
                              //             top: 20.0,
                              //             right: 8.0,
                              //             left: 8.0,
                              //             bottom: 20.0),
                              //         child: Text(
                              //           'Your purchase has been restored!',
                              //           textAlign: TextAlign.center,
                              //           style: kSendButtonTextStyle,
                              //         ),
                              //       )
                              //     ],
                              //   ),
                              //   buttons: [
                              //     DialogButton(
                              //       radius: BorderRadius.circular(10),
                              //       child: Text(
                              //         "COOL",
                              //         style: kSendButtonTextStyle,
                              //       ),
                              //       onPressed: () {
                              //         Navigator.of(context, rootNavigator: true)
                              //             .pop();
                              //         Navigator.of(context, rootNavigator: true)
                              //             .pop();
                              //         Navigator.of(context, rootNavigator: true)
                              //             .pop();
                              //       },
                              //       width: 127,
                              //       height: 52,
                              //     ),
                              //   ],
                              // ).show();
                            } else {
                              toasts.error(
                                  "There was an error. Please try again later.");
                              // Alert(
                              //   context: context,
                              //   style: kWelcomeAlertStyle,
                              //   image: Image.asset(
                              //     "assets/images/avatar_demo.png",
                              //     height: 150,
                              //   ),
                              //   title: "Error",
                              //   content: Column(
                              //     children: <Widget>[
                              //       Padding(
                              //         padding: const EdgeInsets.only(
                              //             top: 20.0,
                              //             right: 8.0,
                              //             left: 8.0,
                              //             bottom: 20.0),
                              //         child: Text(
                              //           'There was an error. Please try again later',
                              //           textAlign: TextAlign.center,
                              //           style: kSendButtonTextStyle,
                              //         ),
                              //       )
                              //     ],
                              //   ),
                              //   buttons: [
                              //     DialogButton(
                              //       radius: BorderRadius.circular(10),
                              //       child: Text(
                              //         "COOL",
                              //         style: kSendButtonTextStyle,
                              //       ),
                              //       onPressed: () {
                              //         Navigator.of(context, rootNavigator: true)
                              //             .pop();
                              //       },
                              //       width: 127,
                              //       height: 52,
                              //     ),
                              //   ],
                              // ).show();
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
                            }
                            // Alert(
                            //   context: context,
                            //   style: kWelcomeAlertStyle,
                            //   image: Image.asset(
                            //     "assets/images/avatar_demo.png",
                            //     height: 150,
                            //   ),
                            //   title: "Error",
                            //   content: Column(
                            //     children: <Widget>[
                            //       Padding(
                            //         padding: const EdgeInsets.only(
                            //             top: 20.0,
                            //             right: 8.0,
                            //             left: 8.0,
                            //             bottom: 20.0),
                            //         child: Text(
                            //           'There was an error. Please try again later',
                            //           textAlign: TextAlign.center,
                            //           style: kSendButtonTextStyle,
                            //         ),
                            //       )
                            //     ],
                            //   ),
                            //   buttons: [
                            //     DialogButton(
                            //       radius: BorderRadius.circular(10),
                            //       child: Text(
                            //         "COOL",
                            //         style: kSendButtonTextStyle,
                            //       ),
                            //       onPressed: () {
                            //         Navigator.of(context, rootNavigator: true)
                            //             .pop();
                            //       },
                            //       width: 127,
                            //       height: 52,
                            //     ),
                            //   ],
                            // ).show();
                          }
                          return UpgradeScreen();
                        },
                      )
                    ],
                  )));
        }
      }
    }
    return Scaffold(
        appBar: AppBar(title: Text("Upsell Screen")),
        body: Center(
          child: Text("Loading..."),
        ));
  }
}
// class UpsellScreen extends StatefulWidget {
//   final Offerings offerings;

//   UpsellScreen({Key key, @required this.offerings}) : super(key: key);

//   @override
//   _UpsellScreenState createState() => _UpsellScreenState();
// }

// class _UpsellScreenState extends State<UpsellScreen> {
//   _launchURLWebsite(String zz) async {
//     if (await canLaunch(zz)) {
//       await launch(zz);
//     } else {
//       throw 'Could not launch $zz';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (widget.offerings != null) {
//       print('offeringS is not null');
//       print(widget.offerings.current.toString());
//       print('--');
//       print(widget.offerings.toString());
//       final offering = widget.offerings.current;
//       if (offering != null) {
//         final yearly = offering.lifetime;
//         if (yearly != null) {
//           return Scaffold(
//               body: Center(
//             child: SingleChildScrollView(
//               child: Container(
//                 height: MediaQuery.of(context).size.height,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: <Widget>[
//                     Text(
//                       'Thanks for your interest in our app!',
//                       textAlign: TextAlign.center,
//                       style: kSendButtonTextStyle,
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.all(18.0),
//                       child: Container(
//                         height: 100,
//                         child: FlareActor(
//                           "assets/animations/Premium.flr",
//                           isPaused: false,
//                           alignment: Alignment.center,
//                           animation: "premium",
//                         ),
//                       ),
//                     ),
//                     Text(
//                       'Choose one of the plan to continue to get access to all the app content.\n',
//                       textAlign: TextAlign.center,
//                       style: kSendButtonTextStyle,
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: PurchaseButton(package: yearly),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.all(18.0),
//                       child: GestureDetector(
//                         child: Container(
//                           decoration: new BoxDecoration(
//                             borderRadius:
//                                 new BorderRadius.all(Radius.circular(10)),
//                           ),
//                           child: Padding(
//                             padding: const EdgeInsets.all(18.0),
//                             child: Text(
//                               'Restore Purchase',
//                               style: kSendButtonTextStyle.copyWith(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.normal,
//                               ),
//                             ),
//                           ),
//                         ),
// onTap: () async {
//   try {
//     print('now trying to restore');
//     PurchaserInfo restoredInfo =
//         await Purchases.restoreTransactions();
//     print('restore completed');
//     print(restoredInfo.toString());

//     appData.isPro = restoredInfo
//         .entitlements.all["prism_premium"].isActive;

//     print('is user pro? ${appData.isPro}');

//     if (appData.isPro) {
//       main.prefs.put('premium', appData.isPro);
//       toasts.premiumSuccess();
//       Alert(
//         context: context,
//         style: kWelcomeAlertStyle,
//         image: Image.asset(
//           "assets/images/avatar_demo.png",
//           height: 150,
//         ),
//         title: "Congratulations",
//         content: Column(
//           children: <Widget>[
//             Padding(
//               padding: const EdgeInsets.only(
//                   top: 20.0,
//                   right: 8.0,
//                   left: 8.0,
//                   bottom: 20.0),
//               child: Text(
//                 'Your purchase has been restored!',
//                 textAlign: TextAlign.center,
//                 style: kSendButtonTextStyle,
//               ),
//             )
//           ],
//         ),
//         buttons: [
//           DialogButton(
//             radius: BorderRadius.circular(10),
//             child: Text(
//               "COOL",
//               style: kSendButtonTextStyle,
//             ),
//             onPressed: () {
//               Navigator.of(context, rootNavigator: true)
//                   .pop();
//               Navigator.of(context, rootNavigator: true)
//                   .pop();
//               Navigator.of(context, rootNavigator: true)
//                   .pop();
//             },
//             width: 127,
//             height: 52,
//           ),
//         ],
//       ).show();
//     } else {
//       Alert(
//         context: context,
//         style: kWelcomeAlertStyle,
//         image: Image.asset(
//           "assets/images/avatar_demo.png",
//           height: 150,
//         ),
//         title: "Error",
//         content: Column(
//           children: <Widget>[
//             Padding(
//               padding: const EdgeInsets.only(
//                   top: 20.0,
//                   right: 8.0,
//                   left: 8.0,
//                   bottom: 20.0),
//               child: Text(
//                 'There was an error. Please try again later',
//                 textAlign: TextAlign.center,
//                 style: kSendButtonTextStyle,
//               ),
//             )
//           ],
//         ),
//         buttons: [
//           DialogButton(
//             radius: BorderRadius.circular(10),
//             child: Text(
//               "COOL",
//               style: kSendButtonTextStyle,
//             ),
//             onPressed: () {
//               Navigator.of(context, rootNavigator: true)
//                   .pop();
//             },
//             width: 127,
//             height: 52,
//           ),
//         ],
//       ).show();
//     }
//   } on PlatformException catch (e) {
//     print('----xx-----');
//     var errorCode =
//         PurchasesErrorHelper.getErrorCode(e);
//     if (errorCode ==
//         PurchasesErrorCode.purchaseCancelledError) {
//       print("User cancelled");
//     } else if (errorCode ==
//         PurchasesErrorCode.purchaseNotAllowedError) {
//       print("User not allowed to purchase");
//     }
//     Alert(
//       context: context,
//       style: kWelcomeAlertStyle,
//       image: Image.asset(
//         "assets/images/avatar_demo.png",
//         height: 150,
//       ),
//       title: "Error",
//       content: Column(
//         children: <Widget>[
//           Padding(
//             padding: const EdgeInsets.only(
//                 top: 20.0,
//                 right: 8.0,
//                 left: 8.0,
//                 bottom: 20.0),
//             child: Text(
//               'There was an error. Please try again later',
//               textAlign: TextAlign.center,
//               style: kSendButtonTextStyle,
//             ),
//           )
//         ],
//       ),
//       buttons: [
//         DialogButton(
//           radius: BorderRadius.circular(10),
//           child: Text(
//             "COOL",
//             style: kSendButtonTextStyle,
//           ),
//           onPressed: () {
//             Navigator.of(context, rootNavigator: true)
//                 .pop();
//           },
//           width: 127,
//           height: 52,
//         ),
//       ],
//     ).show();
//   }
//   return UpgradeScreen();
// },
// ),
//                     ),
//                     SizedBox(
//                       height: 20.0,
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.all(18.0),
//                       child: GestureDetector(
//                         onTap: () {
//                           _launchURLWebsite('https://google.com');
//                         },
//                         child: Text(
//                           'Privacy Policy (click to read)',
//                           style: kSendButtonTextStyle.copyWith(
//                             fontSize: 16,
//                             fontWeight: FontWeight.normal,
//                           ),
//                         ),
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.all(18.0),
//                       child: GestureDetector(
//                         onTap: () {
//                           _launchURLWebsite('https://yahoo.com');
//                         },
//                         child: Text(
//                           'Term of Use (click to read)',
//                           style: kSendButtonTextStyle.copyWith(
//                             fontSize: 16,
//                             fontWeight: FontWeight.normal,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ));
//         }
//       }
//     }
//     return Scaffold(
//         body: Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: <Widget>[
//           Padding(
//             padding: const EdgeInsets.all(18.0),
//             child: Icon(
//               Icons.error,
//               size: 44.0,
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(12.0),
//             child: Text(
//               "There was an error. Please check that your device is allowed to make purchases and try again. Please contact us at xxx@xxx.com if the problem persists.",
//               textAlign: TextAlign.center,
//               style: kSendButtonTextStyle,
//             ),
//           ),
//         ],
//       ),
//     ));
//   }
// }

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
      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
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
                      // Alert(
                      //   context: context,
                      //   style: kWelcomeAlertStyle,
                      //   image: Image.asset(
                      //     "assets/images/avatar_demo.png",
                      //     height: 150,
                      //   ),
                      //   title: "Congratulations",
                      //   content: Column(
                      //     children: <Widget>[
                      //       Padding(
                      //         padding: const EdgeInsets.only(
                      //             top: 20.0,
                      //             right: 8.0,
                      //             left: 8.0,
                      //             bottom: 20.0),
                      //         child: Text(
                      //           'Well done, you now have full access to the app',
                      //           textAlign: TextAlign.center,
                      //           style: kSendButtonTextStyle,
                      //         ),
                      //       )
                      //     ],
                      //   ),
                      //   buttons: [
                      //     DialogButton(
                      //       radius: BorderRadius.circular(10),
                      //       child: Text(
                      //         "COOL",
                      //         style: kSendButtonTextStyle,
                      //       ),
                      //       onPressed: () {
                      //         Navigator.of(context, rootNavigator: true).pop();
                      //         Navigator.of(context, rootNavigator: true).pop();
                      //         Navigator.of(context, rootNavigator: true).pop();
                      //       },
                      //       width: 127,
                      //       height: 52,
                      //     ),
                      //   ],
                      // ).show();
                    } else {
                      toasts
                          .error("There was an error, please try again later.");
                      // Alert(
                      //   context: context,
                      //   style: kWelcomeAlertStyle,
                      //   image: Image.asset(
                      //     "assets/images/avatar_demo.png",
                      //     height: 150,
                      //   ),
                      //   title: "Error",
                      //   content: Column(
                      //     children: <Widget>[
                      //       Padding(
                      //         padding: const EdgeInsets.only(
                      //             top: 20.0,
                      //             right: 8.0,
                      //             left: 8.0,
                      //             bottom: 20.0),
                      //         child: Text(
                      //           'There was an error. Please try again later',
                      //           textAlign: TextAlign.center,
                      //           style: kSendButtonTextStyle,
                      //         ),
                      //       )
                      //     ],
                      //   ),
                      //   buttons: [
                      //     DialogButton(
                      //       radius: BorderRadius.circular(10),
                      //       child: Text(
                      //         "COOL",
                      //         style: kSendButtonTextStyle,
                      //       ),
                      //       onPressed: () {
                      //         Navigator.of(context, rootNavigator: true).pop();
                      //       },
                      //       width: 127,
                      //       height: 52,
                      //     ),
                      //   ],
                      // ).show();
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
                    }
                    // Alert(
                    //   context: context,
                    //   style: kWelcomeAlertStyle,
                    //   image: Image.asset(
                    //     "assets/images/avatar_demo.png",
                    //     height: 150,
                    //   ),
                    //   title: "Error",
                    //   content: Column(
                    //     children: <Widget>[
                    //       Padding(
                    //         padding: const EdgeInsets.only(
                    //             top: 20.0, right: 8.0, left: 8.0, bottom: 20.0),
                    //         child: Text(
                    //           'There was an error. Please try again later',
                    //           textAlign: TextAlign.center,
                    //           style: kSendButtonTextStyle,
                    //         ),
                    //       )
                    //     ],
                    //   ),
                    //   buttons: [
                    //     DialogButton(
                    //       radius: BorderRadius.circular(10),
                    //       child: Text(
                    //         "COOL",
                    //         style: kSendButtonTextStyle,
                    //       ),
                    //       onPressed: () {
                    //         Navigator.of(context, rootNavigator: true).pop();
                    //       },
                    //       width: 127,
                    //       height: 52,
                    //     ),
                    //   ],
                    // ).show();
                  }
                  return UpgradeScreen();
                },
                padding: const EdgeInsets.all(0.0),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.75,
                  decoration: BoxDecoration(
                      color: Color(0xFFE57697),
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: Text(
                          'Buy ${widget.package.product.title}',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.27,
                        child: Text(
                          '${widget.package.product.priceString}',
                          style: TextStyle(fontSize: 20),
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
                    fontSize: 16, fontWeight: FontWeight.normal),
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
    return Scaffold(
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
        ));
  }
}
