import 'dart:io';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/pages/home/collections/collectionScreen.dart';
import 'package:Prism/ui/pages/home/wallpapers/homeScreen.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/core/categoriesBar.dart';
import 'package:Prism/ui/widgets/home/core/offlineBanner.dart';
import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/theme/toasts.dart' as toasts;

// PageController pageController = PageController();
TabController tabController;

class PageManager extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomBar(
      child: PageManagerChild(),
    );
  }
}

class PageManagerChild extends StatefulWidget {
  @override
  _PageManagerChildState createState() => _PageManagerChildState();
}

class _PageManagerChildState extends State<PageManagerChild>
    with SingleTickerProviderStateMixin {
  int page = 0;
  int linkOpened = 0;
  bool result = true;

  RateMyApp rateMyApp = RateMyApp(
    minDays: 0, //0
    minLaunches: 5, //5
    remindDays: 7, //7
    remindLaunches: 10, //10
    googlePlayIdentifier: 'com.hash.prism',
  );

  Future<void> checkConnection() async {
    result = await DataConnectionChecker().hasConnection;
    if (result) {
      debugPrint("Internet working as expected!");
      setState(() {});
      // return true;
    } else {
      debugPrint("Not connected to Internet!");
      setState(() {});
      // return false;
    }
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    // Provider.of<TabProvider>(context, listen: false)
    //     .updateSelectedTab("Wallpapers");
    checkConnection();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await rateMyApp.init();
      if (mounted && rateMyApp.shouldOpenDialog) {
        rateMyApp.showStarRateDialog(
          context,
          title: 'RATE PRISM',
          message:
              'You like Prism? Then please take a little bit of your time to leave a rating :',
          actionsBuilder: (context, stars) {
            return [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: FlatButton(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  color: config.Colors().mainAccentColor(1),
                  onPressed: () async {
                    debugPrint(
                        'Thanks for the ${stars == null ? '0' : stars.round().toString()} star(s) !');
                    if (stars <= 3) {
                      if (Platform.isAndroid) {
                        final androidInfo =
                            await DeviceInfoPlugin().androidInfo;
                        final release = androidInfo.version.release;
                        final sdkInt = androidInfo.version.sdkInt;
                        final manufacturer = androidInfo.manufacturer;
                        final model = androidInfo.model;
                        debugPrint(
                            'Android $release (SDK $sdkInt), $manufacturer $model');
                        launch(
                            "mailto:hash.studios.inc@gmail.com?subject=%5BCUSTOMER%20FEEDBACK%5D&body=----x-x-x----%0D%0ADevice%20Info%20-%0D%0A%0D%0AAndroid%20Version%3A%20Android%20$release%0D%0ASDK%20Number%3A%20SDK%20$sdkInt%0D%0ADevice%20Manufacturer%3A%20$manufacturer%0D%0ADevice%20Model%3A%20$model%0D%0A----x-x-x----%0D%0A%0D%0AEnter%20your%20feedback%20below%20---");
                      }
                    } else {
                      toasts.codeSend("Thank You for your Rating!");
                      launch(
                          "https://play.google.com/store/apps/details?id=com.hash.prism");
                    }

                    analytics.logEvent(
                        name: "rating_given", parameters: {'rating': stars});
                    await rateMyApp
                        .callEvent(RateMyAppEventType.rateButtonPressed);
                    Navigator.pop<RateMyAppDialogButton>(
                        context, RateMyAppDialogButton.rate);
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ];
          },
          dialogStyle: DialogStyle(
            dialogShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            messageStyle: Theme.of(context)
                .textTheme
                .headline6
                .copyWith(color: Theme.of(context).accentColor),
            messagePadding: const EdgeInsets.only(bottom: 20),
            titleStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Theme.of(context).accentColor),
          ),
          ignoreNativeDialog: Platform.isAndroid,
          starRatingOptions: StarRatingOptions(
              initialRating: 5,
              starsFillColor: config.Colors().mainAccentColor(1),
              starsBorderColor: config.Colors().mainAccentColor(1)),
          onDismissed: () =>
              rateMyApp.callEvent(RateMyAppEventType.laterButtonPressed),
        );
      }
    });
  }

  Future<bool> initDynamicLinks(BuildContext context) async {
    final PendingDynamicLinkData data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    final Uri deepLink = data?.link;

    if (deepLink != null && linkOpened == 0) {
      debugPrint("opened while closed altogether via deep link");
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
            Navigator.pushNamed(context, photographerProfileRoute, arguments: [
              deepLink.queryParameters["name"],
              deepLink.queryParameters["email"],
              deepLink.queryParameters["userPhoto"],
              deepLink.queryParameters["premium"] == "true",
              deepLink.queryParameters["twitter"],
              deepLink.queryParameters["instagram"],
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
      debugPrint("opened while closed altogether via deep link2345");
    }

    FirebaseDynamicLinks.instance.onLink(
        onSuccess: (PendingDynamicLinkData dynamicLink) async {
      final Uri deepLink = dynamicLink?.link;

      if (deepLink != null) {
        debugPrint("opened while bg via deep link1");
        if (deepLink.pathSegments[0] == "share") {
          Future.delayed(const Duration()).then(
              (value) => Navigator.pushNamed(context, shareRoute, arguments: [
                    deepLink.queryParameters["id"],
                    deepLink.queryParameters["provider"],
                    deepLink.queryParameters["url"],
                    deepLink.queryParameters["thumb"],
                  ]));
        } else if (deepLink.pathSegments[0] == "user") {
          Future.delayed(const Duration()).then((value) => Navigator.pushNamed(
                  context, photographerProfileRoute,
                  arguments: [
                    deepLink.queryParameters["name"],
                    deepLink.queryParameters["email"],
                    deepLink.queryParameters["userPhoto"],
                    deepLink.queryParameters["premium"] == "true",
                    deepLink.queryParameters["twitter"],
                    deepLink.queryParameters["instagram"],
                  ]));
        } else if (deepLink.pathSegments[0] == "setup") {
          Future.delayed(const Duration()).then((value) =>
              Navigator.pushNamed(context, shareSetupViewRoute, arguments: [
                deepLink.queryParameters["name"],
                deepLink.queryParameters["thumbUrl"],
              ]));
        } else {}

        debugPrint("opened while bg via deep link2345");
      }
    }, onError: (OnLinkErrorException e) async {
      debugPrint('onLinkError');
      debugPrint(e.message);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 1), () => initDynamicLinks(context));
    return WillPopScope(
      onWillPop: () async {
        if (tabController.index != 0) {
          tabController.animateTo(0);
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
              tabs: [
                Tab(
                  // icon: Icon(
                  //   JamIcons.picture,
                  //   color: Theme.of(context).accentColor,
                  // ),
                  child: Text(
                    "Wallpapers",
                    style: Theme.of(context)
                        .textTheme
                        .bodyText2
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
                // Tab(
                //   icon: Icon(
                //     JamIcons.instant_picture,
                //     color: Theme.of(context).accentColor,
                //   ),
                // ),
                Tab(
                  // icon: Icon(
                  //   JamIcons.pictures,
                  //   color: Theme.of(context).accentColor,
                  // ),
                  child: Text(
                    "Collections",
                    style: Theme.of(context)
                        .textTheme
                        .bodyText2
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                )
              ]),
        ),
        body: Stack(
          children: <Widget>[
            TabBarView(controller: tabController, children: const [
              HomeScreen(),
              // const HomeSetupScreen(),
              CollectionScreen()
            ]),
            if (!result) ConnectivityWidget() else Container(),
          ],
        ),
      ),
    );
  }
}
