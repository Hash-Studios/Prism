import 'dart:io';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/tabs/provider/tabsProvider.dart';
import 'package:Prism/global/globals.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/pages/home/collections/collectionScreen.dart';
import 'package:Prism/ui/pages/home/wallpapers/homeScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/core/categoriesBar.dart';
import 'package:Prism/ui/widgets/home/core/offlineBanner.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;

PageController pageController = PageController();

class PageManager extends StatefulWidget {
  @override
  _PageManagerState createState() => _PageManagerState();
}

class _PageManagerState extends State<PageManager> {
  int page = 0;
  int linkOpened = 0;
  bool result = true;

  RateMyApp rateMyApp = RateMyApp(
    preferencesPrefix: 'rateMyApp_',
    minDays: 0, //0
    minLaunches: 5, //5
    remindDays: 7, //7
    remindLaunches: 10, //10
    googlePlayIdentifier: 'com.hash.prism',
  );

  void checkConnection() async {
    result = await DataConnectionChecker().hasConnection;
    if (result) {
      print("Internet working as expected!");
    } else {
      print("Not connected to Internet!");
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    Provider.of<TabProvider>(context, listen: false)
        .updateSelectedTab("Wallpapers");
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
                  shape: StadiumBorder(),
                  color: config.Colors().mainAccentColor(1),
                  onPressed: () async {
                    print('Thanks for the ' +
                        (stars == null ? '0' : stars.round().toString()) +
                        ' star(s) !');
                    if (stars <= 3) {
                      if (Platform.isAndroid) {
                        var androidInfo = await DeviceInfoPlugin().androidInfo;
                        var release = androidInfo.version.release;
                        var sdkInt = androidInfo.version.sdkInt;
                        var manufacturer = androidInfo.manufacturer;
                        var model = androidInfo.model;
                        print(
                            'Android $release (SDK $sdkInt), $manufacturer $model');
                        launch(
                            "mailto:hash.studios.inc@gmail.com?subject=%5BCUSTOMER%20FEEDBACK%5D&body=----x-x-x----%0D%0ADevice%20Info%20-%0D%0A%0D%0AAndroid%20Version%3A%20Android%20$release%0D%0ASDK%20Number%3A%20SDK%20$sdkInt%0D%0ADevice%20Manufacturer%3A%20$manufacturer%0D%0ADevice%20Model%3A%20$model%0D%0A----x-x-x----%0D%0A%0D%0AEnter%20your%20feedback%20below%20---");
                      }
                    } else {
                      toasts.codeSend("Thank You for your Rating!");
                      launch(
                          "https://play.google.com/store/apps/details?id=com.hash.prism");
                    }
                    ;
                    analytics.logEvent(
                        name: "rating_given", parameters: {'rating': stars});
                    await rateMyApp
                        .callEvent(RateMyAppEventType.rateButtonPressed);
                    Navigator.pop<RateMyAppDialogButton>(
                        context, RateMyAppDialogButton.rate);
                  },
                  child: Text(
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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            messageStyle: Theme.of(context)
                .textTheme
                .headline6
                .copyWith(color: Theme.of(context).accentColor),
            messagePadding: EdgeInsets.only(bottom: 20),
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

  void initDynamicLinks(BuildContext context) async {
    final PendingDynamicLinkData data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    final Uri deepLink = data?.link;

    if (deepLink != null && linkOpened == 0) {
      print("opened while closed altogether via deep link");
      if (deepLink.pathSegments[0] == "share") {
        Future.delayed(Duration(seconds: 0)).then(
            (value) => Navigator.pushNamed(context, ShareRoute, arguments: [
                  deepLink.queryParameters["id"],
                  deepLink.queryParameters["provider"],
                  deepLink.queryParameters["url"],
                  deepLink.queryParameters["thumb"],
                ]));
        linkOpened = 1;
      } else if (deepLink.pathSegments[0] == "user") {
        Future.delayed(Duration(seconds: 0)).then((value) =>
            Navigator.pushNamed(context, PhotographerProfileRoute, arguments: [
              deepLink.queryParameters["name"],
              deepLink.queryParameters["email"],
              deepLink.queryParameters["userPhoto"],
              deepLink.queryParameters["premium"] == "true" ? true : false,
              deepLink.queryParameters["twitter"],
              deepLink.queryParameters["instagram"],
            ]));
        linkOpened = 1;
      } else if (deepLink.pathSegments[0] == "setup") {
        Future.delayed(Duration(seconds: 0))
            .then((value) => main.prefs.get("isLoggedin")
                ? Navigator.pushNamed(context, ShareSetupViewRoute, arguments: [
                    deepLink.queryParameters["name"],
                    deepLink.queryParameters["thumbUrl"],
                  ])
                : googleSignInPopUp(context, () {
                    Navigator.pushNamed(context, ShareSetupViewRoute,
                        arguments: [
                          deepLink.queryParameters["name"],
                          deepLink.queryParameters["thumbUrl"],
                        ]);
                  }));
        linkOpened = 1;
      } else {}
      print("opened while closed altogether via deep link2345");
    }

    FirebaseDynamicLinks.instance.onLink(
        onSuccess: (PendingDynamicLinkData dynamicLink) async {
      final Uri deepLink = dynamicLink?.link;

      if (deepLink != null) {
        print("opened while bg via deep link1");
        if (deepLink.pathSegments[0] == "share") {
          Future.delayed(Duration(seconds: 0)).then(
              (value) => Navigator.pushNamed(context, ShareRoute, arguments: [
                    deepLink.queryParameters["id"],
                    deepLink.queryParameters["provider"],
                    deepLink.queryParameters["url"],
                    deepLink.queryParameters["thumb"],
                  ]));
        } else if (deepLink.pathSegments[0] == "user") {
          Future.delayed(Duration(seconds: 0)).then((value) => Navigator
                  .pushNamed(context, PhotographerProfileRoute, arguments: [
                deepLink.queryParameters["name"],
                deepLink.queryParameters["email"],
                deepLink.queryParameters["userPhoto"],
                deepLink.queryParameters["premium"] == "true" ? true : false,
                deepLink.queryParameters["twitter"],
                deepLink.queryParameters["instagram"],
              ]));
        } else if (deepLink.pathSegments[0] == "setup") {
          Future.delayed(Duration(seconds: 0)).then((value) => main.prefs
                  .get("isLoggedin")
              ? Navigator.pushNamed(context, ShareSetupViewRoute, arguments: [
                  deepLink.queryParameters["name"],
                  deepLink.queryParameters["thumbUrl"],
                ])
              : googleSignInPopUp(context, () {
                  Navigator.pushNamed(context, ShareSetupViewRoute, arguments: [
                    deepLink.queryParameters["name"],
                    deepLink.queryParameters["thumbUrl"],
                  ]);
                }));
        } else {}

        print("opened while bg via deep link2345");
      }
    }, onError: (OnLinkErrorException e) async {
      print('onLinkError');
      print(e.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 1), () => initDynamicLinks(context));
    return WillPopScope(
      onWillPop: () async {
        if (page != 0) {
          pageController.jumpTo(0);
        } else {
          return true;
        }
        return false;
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: PreferredSize(
            child: CategoriesBar(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height),
            preferredSize: Size(double.infinity, 55),
          ),
          body: Stack(
            children: <Widget>[
              BottomBar(
                child: PageView.builder(
                    onPageChanged: (index) {
                      print("Index cat: " + index.toString());
                      setState(() {
                        page = index;
                      });
                      categoryController.scrollToIndex(index,
                          preferPosition: AutoScrollPosition.begin);
                      if (index == 0) {
                        Provider.of<TabProvider>(context, listen: false)
                            .updateSelectedTab("Wallpapers");
                      } else if (index == 1) {
                        Provider.of<TabProvider>(context, listen: false)
                            .updateSelectedTab("Collections");
                      }
                    },
                    controller: pageController,
                    itemCount: 2,
                    itemBuilder: (context, index) {
                      print("Index : " + index.toString());
                      if (index == 0) {
                        return HomeScreen();
                      } else if (index == 1) {
                        return CollectionScreen();
                      }
                      return UndefinedScreen();
                    }),
              ),
              !result ? ConnectivityWidget() : Container(),
            ],
          )),
    );
  }
}
