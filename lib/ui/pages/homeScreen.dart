import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/router.dart';
import 'package:Prism/routing_constants.dart';
import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:Prism/ui/widgets/categoriesBar.dart';
import 'package:Prism/ui/widgets/changelogPopUp.dart';
import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;

class HomeScreen extends StatefulWidget {
  HomeScreen({
    Key key,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<bool> onWillPop() async {
    String route = currentRoute;
    currentRoute = previousRoute;
    previousRoute = route;
    print(currentRoute);
    return true;
  }

  bool isNew;
  @override
  void initState() {
    isNew = true;
    super.initState();
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
    if (isNew) {
      Future.delayed(Duration(seconds: 0))
          .then((value) => showChangelogCheck(context));
    }
    initDynamicLinks(context);
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: PreferredSize(
            child: CategoriesBar(
              current: "Home",
            ),
            preferredSize: Size(double.infinity, 55),
          ),
          body: BottomBar(
            child: GridLoader(
              future: Provider.of<WallHavenProvider>(context, listen: false)
                  .getData(),
              provider: "WallHaven",
            ),
          )),
    );
  }
}
