import 'dart:io';
import 'package:Prism/data/ads/adsNotifier.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/pages/home/collections/collectionScreen.dart';
import 'package:Prism/ui/pages/home/wallpapers/homeScreen.dart';
import 'package:Prism/ui/pages/home/wallpapers/followingScreen.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/core/categoriesBar.dart';
import 'package:Prism/ui/widgets/home/core/offlineBanner.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:animations/animations.dart';
import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
// import 'package:rate_my_app/rate_my_app.dart';
// import 'package:smooth_star_rating/smooth_star_rating.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/main.dart' as main;
import 'package:quick_actions/quick_actions.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';

TabController? tabController;

class PageManager extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomBar(
      child: PageManagerChild(),
    );
  }
}

// RateMyApp rateMyApp = RateMyApp(
//   minDays: 0, //0
//   minLaunches: 5, //5
//   remindDays: 7, //7
//   remindLaunches: 10, //10
//   googlePlayIdentifier: 'com.hash.prism',
// );

class PageManagerChild extends StatefulWidget {
  @override
  _PageManagerChildState createState() => _PageManagerChildState();
}

class _PageManagerChildState extends State<PageManagerChild>
    with SingleTickerProviderStateMixin {
  int page = 0;
  int linkOpened = 0;
  bool result = true;
  final box = Hive.box('localFav');
  String shortcut = "No Action Set";

  Future<void> checkConnection() async {
    result = await DataConnectionChecker().hasConnection;
    if (result) {
      logger.d("Internet working as expected!");
      setState(() {});
      // return true;
    } else {
      logger.d("Not connected to Internet!");
      setState(() {});
      // return false;
    }
  }

  Future<void> saveFavToLocal() async {
    if (globals.prismUser.loggedIn) {
      await Provider.of<FavouriteProvider>(context, listen: false)
          .getDataBase()
          .then(
        (value) {
          for (final element in value!) {
            box.put(element['id'].toString(), true);
          }
          box.put('dataSaved', true);
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    tabController =
        TabController(length: globals.followersTab ? 3 : 2, vsync: this);
    Provider.of<AdsNotifier>(context, listen: false).createRewardedAd();
    final QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      setState(() {
        if (shortcutType != null) shortcut = shortcutType;
      });
      if (shortcutType == 'Follow_Feed') {
        logger.d('Follow_Feed');
        if (globals.followersTab) {
          tabController!.animateTo(1);
        }
      } else if (shortcutType == 'Collections') {
        logger.d('Collections');
        if (globals.followersTab) {
          tabController!.animateTo(2);
        } else {
          tabController!.animateTo(1);
        }
      } else if (shortcutType == 'Setups') {
        logger.d('Setups');
        navStack.last == "Setups"
            ? logger.d("Currently on Setups")
            : navStack.last == "Home"
                ? Navigator.of(context).pushNamed(setupRoute)
                : Navigator.of(context).pushNamed(setupRoute);
      } else if (shortcutType == 'Downloads') {
        logger.d('Downloads');
        Navigator.pushNamed(context, downloadRoute);
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      // NOTE: This second action icon will only work on Android.
      // In a real world project keep the same file name for both platforms.
      const ShortcutItem(
          type: 'Follow_Feed',
          localizedTitle: 'Feed',
          icon: '@drawable/ic_feed'),
      const ShortcutItem(
          type: 'Collections',
          localizedTitle: 'Collections',
          icon: '@drawable/ic_collections'),
      const ShortcutItem(
          type: 'Setups',
          localizedTitle: 'Setups',
          icon: '@drawable/ic_setups'),
      const ShortcutItem(
          type: 'Downloads',
          localizedTitle: 'Downloads',
          icon: '@drawable/ic_downloads'),
    ]);
    if (box.get('dataSaved', defaultValue: false) as bool) {
    } else {
      saveFavToLocal();
    }
    checkConnection();
    // WidgetsBinding.instance!.addPostFrameCallback((_) async {
    //   // await rateMyApp.init();
    //   if (mounted &&
    //       rateMyApp.shouldOpenDialog &&
    //       (main.prefs.get("ratedApp", defaultValue: false) == false)) {
    //     showModal(
    //         context: context,
    //         configuration: const FadeScaleTransitionConfiguration(),
    //         builder: (_) => RatePopUp());
    //   }
    // });
  }

  Future<bool> initDynamicLinks(BuildContext context) async {
    final PendingDynamicLinkData data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    final Uri? deepLink = data?.link;

    if (deepLink != null && linkOpened == 0) {
      logger.d("opened while closed altogether via deep link");
      if (deepLink.pathSegments[0] == "share") {
        Future.delayed(const Duration()).then(
            (value) => Navigator.pushNamed(context, shareRoute, arguments: [
                  deepLink.queryParameters["id"],
                  deepLink.queryParameters["provider"],
                  deepLink.queryParameters["url"],
                  deepLink.queryParameters["thumb"],
                ]));
        linkOpened = 1;
      } else if (deepLink.pathSegments[0] == "user") {
        Future.delayed(const Duration()).then((value) =>
            Navigator.pushNamed(context, followerProfileRoute, arguments: [
              deepLink.queryParameters["email"],
            ]));
        linkOpened = 1;
      } else if (deepLink.pathSegments[0] == "setup") {
        Future.delayed(const Duration()).then((value) =>
            Navigator.pushNamed(context, shareSetupViewRoute, arguments: [
              deepLink.queryParameters["name"],
              deepLink.queryParameters["thumbUrl"],
            ]));
        linkOpened = 1;
      } else if (deepLink.pathSegments[0] == "refer") {
        //TODO write code to add coins in friend/user account
        linkOpened = 1;
      } else {}
      logger.d("opened while closed altogether via deep link2345");
    }

    FirebaseDynamicLinks.instance.onLink(
        onSuccess: (PendingDynamicLinkData dynamicLink) async {
      final Uri deepLink = dynamicLink.link;

      if (deepLink != null) {
        logger.d("opened while bg via deep link1");
        if (deepLink.pathSegments[0] == "share") {
          Future.delayed(const Duration()).then(
              (value) => Navigator.pushNamed(context, shareRoute, arguments: [
                    deepLink.queryParameters["id"],
                    deepLink.queryParameters["provider"],
                    deepLink.queryParameters["url"],
                    deepLink.queryParameters["thumb"],
                  ]));
        } else if (deepLink.pathSegments[0] == "user") {
          Future.delayed(const Duration()).then((value) =>
              Navigator.pushNamed(context, followerProfileRoute, arguments: [
                deepLink.queryParameters["email"],
              ]));
        } else if (deepLink.pathSegments[0] == "setup") {
          Future.delayed(const Duration()).then((value) =>
              Navigator.pushNamed(context, shareSetupViewRoute, arguments: [
                deepLink.queryParameters["name"],
                deepLink.queryParameters["thumbUrl"],
              ]));
        } else {}

        logger.d("opened while bg via deep link2345");
      }
    }, onError: (OnLinkErrorException e) async {
      logger.d('onLinkError');
      logger.d(e.message);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () => initDynamicLinks(context));
    return WillPopScope(
      onWillPop: () async {
        if (tabController!.index != 0) {
          tabController!.animateTo(0);
        } else {
          return true;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: const PreferredSize(
            preferredSize: Size(double.infinity, 55),
            child: CategoriesBar(),
          ),
          bottom: TabBar(
              controller: tabController,
              indicatorColor: Theme.of(context).accentColor,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: globals.followersTab
                  ? [
                      Tab(
                        icon: Icon(
                          JamIcons.picture,
                          color: Theme.of(context).accentColor,
                        ),
                      ),
                      Tab(
                        icon: Icon(
                          JamIcons.user_square,
                          color: Theme.of(context).accentColor,
                        ),
                      ),
                      Tab(
                        icon: Icon(
                          JamIcons.pictures,
                          color: Theme.of(context).accentColor,
                        ),
                      )
                    ]
                  : [
                      Tab(
                        icon: Icon(
                          JamIcons.picture,
                          color: Theme.of(context).accentColor,
                        ),
                      ),
                      Tab(
                        icon: Icon(
                          JamIcons.pictures,
                          color: Theme.of(context).accentColor,
                        ),
                      )
                    ]),
        ),
        body: Stack(
          children: <Widget>[
            TabBarView(
              controller: tabController,
              children: (globals.followersTab == true)
                  ? <Widget>[
                      const HomeScreen(),
                      if (globals.prismUser.loggedIn == true)
                        const FollowingScreen()
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Spacer(),
                            Center(
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: const Text(
                                  "Please sign-in to view the latest walls from the artists you follow here.",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 16,
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                googleSignInPopUp(context, () {
                                  main.RestartWidget.restartApp(context);
                                });
                              },
                              style: ButtonStyle(
                                backgroundColor: MaterialStateColor.resolveWith(
                                    (states) => Colors.white),
                              ),
                              child: const SizedBox(
                                width: 60,
                                child: Text(
                                  'SIGN-IN',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFE57697),
                                    fontSize: 15,
                                    fontFamily: "Roboto",
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      const CollectionScreen(),
                    ]
                  : [
                      const HomeScreen(),
                      const CollectionScreen(),
                    ],
            ),
            if (!result) ConnectivityWidget() else Container(),
          ],
        ),
      ),
    );
  }
}

// class RatePopUp extends StatefulWidget {
//   @override
//   _RatePopUpState createState() => _RatePopUpState();
// }

// class _RatePopUpState extends State<RatePopUp> {
//   late double rating;
//   @override
//   void initState() {
//     super.initState();
//     rating = 5;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       title: Text(
//         'Rate Prism',
//         style: TextStyle(
//           fontSize: 20.0,
//           fontWeight: FontWeight.bold,
//           color: Theme.of(context).accentColor,
//         ),
//       ),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             "You like Prism?\nThen please take a little bit of your time to leave a rating :",
//             style: Theme.of(context)
//                 .textTheme
//                 .bodyText2!
//                 .copyWith(color: Theme.of(context).accentColor),
//           ),
//           const SizedBox(height: 24),
//           SmoothStarRating(
//               allowHalfRating: false,
//               onRated: (value) {
//                 if (mounted) {
//                   setState(() {
//                     rating = value;
//                   });
//                 }
//               },
//               rating: rating,
//               size: 40.0,
//               filledIconData: Icons.star_rounded,
//               defaultIconData: Icons.star_border_rounded,
//               color: Theme.of(context).errorColor,
//               borderColor: Theme.of(context).errorColor,
//               spacing: 1)
//         ],
//       ),
//       actions: [
//         FlatButton(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
//           textColor: Theme.of(context).accentColor,
//           onPressed: () {
//             Navigator.pop(context);
//             rateMyApp.callEvent(RateMyAppEventType.laterButtonPressed);
//           },
//           child: const Text(
//             'LATER',
//           ),
//         ),
//         FlatButton(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
//           textColor: Theme.of(context).accentColor,
//           color: Theme.of(context).errorColor,
//           onPressed: () async {
//             Navigator.of(context).pop();
//             logger.d(
//                 'Thanks for the ${rating == null ? '0' : rating.round().toString()} star(s) !');
//             if (rating <= 3) {
//               if (Platform.isAndroid) {
//                 final androidInfo = await DeviceInfoPlugin().androidInfo;
//                 final release = androidInfo.version.release;
//                 final sdkInt = androidInfo.version.sdkInt;
//                 final manufacturer = androidInfo.manufacturer;
//                 final model = androidInfo.model;
//                 logger
//                     .d('Android $release (SDK $sdkInt), $manufacturer $model');
//                 launch(
//                     "mailto:hash.studios.inc@gmail.com?subject=%5BCUSTOMER%20FEEDBACK%5D&body=----x-x-x----%0D%0ADevice%20Info%20-%0D%0A%0D%0AAndroid%20Version%3A%20Android%20$release%0D%0ASDK%20Number%3A%20SDK%20$sdkInt%0D%0ADevice%20Manufacturer%3A%20$manufacturer%0D%0ADevice%20Model%3A%20$model%0D%0A----x-x-x----%0D%0A%0D%0AEnter%20your%20feedback%20below%20---");
//               }
//             } else {
//               toasts.codeSend("Thank You for your Rating!");
//               launch(
//                   "https://play.google.com/store/apps/details?id=com.hash.prism");
//             }
//             await rateMyApp.callEvent(RateMyAppEventType.rateButtonPressed);
//             main.prefs.put("ratedApp", true);
//             Navigator.pop<RateMyAppDialogButton>(
//                 context, RateMyAppDialogButton.rate);
//           },
//           child: const Text(
//             'OK',
//           ),
//         ),
//       ],
//       backgroundColor: Theme.of(context).primaryColor,
//       actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
//     );
//   }
// }
