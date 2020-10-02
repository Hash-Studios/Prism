import 'package:Prism/data/tabs/provider/tabsProvider.dart';
import 'package:Prism/global/globals.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/pages/home/collections/collectionScreen.dart';
import 'package:Prism/ui/pages/home/wallpapers/homeScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/core/categoriesBar.dart';
import 'package:Prism/ui/widgets/home/core/offlineBanner.dart';
import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

PageController pageController = PageController();

class PageManager extends StatefulWidget {
  @override
  _PageManagerState createState() => _PageManagerState();
}

class _PageManagerState extends State<PageManager> {
  int page = 0;
  bool result = true;

  Future<bool> checkConnection() async {
    result = await DataConnectionChecker().hasConnection;
    if (result) {
      debugPrint("Internet working as expected!");
      setState(() {});
      return true;
    } else {
      debugPrint("Not connected to Internet!");
      setState(() {});
      return false;
    }
  }

  @override
  void initState() {
    Provider.of<TabProvider>(context, listen: false)
        .updateSelectedTab("Wallpapers");
    checkConnection();
    super.initState();
  }

  Future<bool> initDynamicLinks(BuildContext context) async {
    final PendingDynamicLinkData data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    final Uri deepLink = data?.link;

    if (deepLink != null) {
      debugPrint("opened while closed altogether via deep link");
      Future.delayed(const Duration(seconds: 0))
          .then((value) => Navigator.pushNamed(context, shareRoute, arguments: [
                deepLink.queryParameters["id"],
                deepLink.queryParameters["provider"],
                deepLink.queryParameters["url"],
                deepLink.queryParameters["thumb"],
              ]));
      debugPrint("opened while closed altogether via deep link2345");
    }

    FirebaseDynamicLinks.instance.onLink(
        onSuccess: (PendingDynamicLinkData dynamicLink) async {
      final Uri deepLink = dynamicLink?.link;

      if (deepLink != null) {
        debugPrint("opened while bg via deep link1");
        Future.delayed(const Duration(seconds: 0)).then(
            (value) => Navigator.pushNamed(context, shareRoute, arguments: [
                  deepLink.queryParameters["id"],
                  deepLink.queryParameters["provider"],
                  deepLink.queryParameters["url"],
                  deepLink.queryParameters["thumb"],
                ]));
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
    initDynamicLinks(context);
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
            preferredSize: const Size(double.infinity, 55),
            child: CategoriesBar(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height),
          ),
          body: Stack(
            children: <Widget>[
              BottomBar(
                child: PageView.builder(
                    onPageChanged: (index) {
                      debugPrint("Index cat: ${index.toString()}");
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
                      debugPrint("Index : ${index.toString()}");
                      if (index == 0) {
                        return HomeScreen();
                      } else if (index == 1) {
                        return const CollectionScreen();
                      }
                      return const UndefinedScreen();
                    }),
              ),
              if (!result) ConnectivityWidget() else Container(),
            ],
          )),
    );
  }
}
