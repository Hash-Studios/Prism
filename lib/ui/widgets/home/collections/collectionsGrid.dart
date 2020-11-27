import 'dart:math';

import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart'
    as CData;

class CollectionsGrid extends StatefulWidget {
  @override
  _CollectionsGridState createState() => _CollectionsGridState();
}

class _CollectionsGridState extends State<CollectionsGrid>
    with TickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;
  bool isLoggedin;
  GlobalKey<RefreshIndicatorState> refreshKey =
      GlobalKey<RefreshIndicatorState>();
  Random r = Random();

  @override
  void initState() {
    checkSignIn();
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = Provider.of<ThemeModel>(context, listen: false)
                .returnThemeType() ==
            "Dark"
        ? TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.white10,
                  end: const Color(0x22FFFFFF),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: const Color(0x22FFFFFF),
                  end: Colors.white10,
                ),
              ),
            ],
          ).animate(_controller)
        : TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.black.withOpacity(.1),
                  end: Colors.black.withOpacity(.14),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.black.withOpacity(.14),
                  end: Colors.black.withOpacity(.1),
                ),
              ),
            ],
          ).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void showPremiumPopUp(Function func) {
    if (main.prefs.get("premium") == false) {
      Navigator.pushNamed(context, premiumRoute);
    } else {
      func();
    }
  }

  Future<void> checkSignIn() async {
    setState(() {
      isLoggedin = main.prefs.get("isLoggedin") as bool;
    });
  }

  void showGooglePopUp(Function func) {
    debugPrint(main.prefs.get("isLoggedin").toString());
    if (main.prefs.get("isLoggedin") == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  Future<void> refreshList() async {
    refreshKey.currentState?.show();
    await Future.delayed(const Duration(milliseconds: 500));
    CData.wallpapersForCollections = [];
    CData.collectionNames = {};
    CData.collections = {};
    CData.getCollections();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshKey,
      onRefresh: refreshList,
      child: GridView.builder(
        controller: controller,
        physics: const ScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
        itemCount:
            CData.collectionNames.isEmpty ? 11 : CData.collectionNames.length,
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent:
                MediaQuery.of(context).orientation == Orientation.portrait
                    ? 300
                    : 250,
            childAspectRatio: 0.6225,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              if (CData.collections == {}) {
              } else {
                if (globals.premiumCollections.contains(
                        CData.collectionNames.toList()[index].toString()) ==
                    false) {
                  Navigator.pushNamed(context, collectionViewRoute, arguments: [
                    CData.collectionNames
                            .toList()[index]
                            .toString()[0]
                            .toUpperCase() +
                        CData.collectionNames
                            .toList()[index]
                            .toString()
                            .substring(1),
                    CData.collections[CData.collectionNames.toList()[index]],
                  ]);
                } else {
                  if (main.prefs.get('premium') == true) {
                    Navigator
                        .pushNamed(context, collectionViewRoute, arguments: [
                      CData.collectionNames
                              .toList()[index]
                              .toString()[0]
                              .toUpperCase() +
                          CData.collectionNames
                              .toList()[index]
                              .toString()
                              .substring(1),
                      CData.collections[CData.collectionNames.toList()[index]],
                    ]);
                  } else {
                    showGooglePopUp(() {
                      showPremiumPopUp(() {
                        main.RestartWidget.restartApp(context);
                      });
                    });
                  }
                }
              }
            },
            child: PremiumBanner(
              comparator: globals.premiumCollections.contains(
                      CData.collectionNames.isEmpty
                          ? "none"
                          : CData.collectionNames.toList()[index].toString()) ==
                  false,
              child: Stack(
                children: <Widget>[
                  Positioned(
                      top: 40,
                      left: 40,
                      child: Container(
                          decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    blurRadius: 20,
                                    offset: const Offset(5, 5),
                                    color: Provider.of<ThemeModel>(context)
                                                .returnThemeType() ==
                                            "Light"
                                        ? Colors.black12
                                        : Colors.black54)
                              ]),
                          height:
                              (MediaQuery.of(context).size.width / 2) / 0.6225 -
                                  63.5,
                          width: MediaQuery.of(context).size.width / 2 - 59)),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: 25,
                        left: 25,
                      ),
                      child: CData.collectionNames.toList().isNotEmpty
                          ? Text(
                              CData.collectionNames
                                  .toList()[index]
                                  .toString()
                                  .toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .headline2
                                  .copyWith(
                                      fontSize: 16,
                                      color: Theme.of(context).accentColor,
                                      fontWeight: FontWeight.bold),
                            )
                          : Text(
                              "LOADING",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .headline2
                                  .copyWith(
                                      fontSize: 16,
                                      color: Provider.of<ThemeModel>(context)
                                                  .returnThemeType() ==
                                              "Light"
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  Positioned(
                      top: 20,
                      left: 20,
                      child: Container(
                          decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    blurRadius: 20,
                                    offset: const Offset(5, 5),
                                    color: Provider.of<ThemeModel>(context)
                                                .returnThemeType() ==
                                            "Light"
                                        ? Colors.black26
                                        : Colors.black54)
                              ]),
                          height:
                              (MediaQuery.of(context).size.width / 2) / 0.6225 -
                                  108.5,
                          width: MediaQuery.of(context).size.width / 2 - 59)),
                  Positioned(
                      top: 20,
                      left: 20,
                      child: Container(
                          decoration: CData.collectionNames.isEmpty
                              ? BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : CData
                                          .collections[CData.collectionNames
                                              .toList()[index]
                                              .toString()]
                                          .length ==
                                      1
                                  ? BoxDecoration(
                                      color: animation.value,
                                      borderRadius: BorderRadius.circular(20),
                                      image: DecorationImage(
                                          image: CachedNetworkImageProvider(
                                            CData.collections[CData
                                                        .collectionNames
                                                        .toList()[index]
                                                        .toString()][0]
                                                    ["wallpaper_thumb"]
                                                .toString(),
                                          ),
                                          fit: BoxFit.cover))
                                  : BoxDecoration(
                                      color: animation.value,
                                      borderRadius: BorderRadius.circular(20),
                                      image: DecorationImage(
                                          image: CachedNetworkImageProvider(
                                            CData.collections[CData
                                                        .collectionNames
                                                        .toList()[index]
                                                        .toString()][1]
                                                    ["wallpaper_thumb"]
                                                .toString(),
                                          ),
                                          fit: BoxFit.cover)),
                          height:
                              (MediaQuery.of(context).size.width / 2) / 0.6225 -
                                  108.5,
                          width: MediaQuery.of(context).size.width / 2 - 59)),
                  Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                          decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    blurRadius: 20,
                                    offset: const Offset(5, 5),
                                    color: Provider.of<ThemeModel>(context)
                                                .returnThemeType() ==
                                            "Light"
                                        ? Colors.black26
                                        : Colors.black54)
                              ]),
                          height:
                              (MediaQuery.of(context).size.width / 2) / 0.6225 -
                                  108.5,
                          width: MediaQuery.of(context).size.width / 2 - 59)),
                  Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                          decoration: CData.collectionNames.isEmpty
                              ? BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        CData.collections[CData.collectionNames
                                                    .toList()[index]
                                                    .toString()][0]
                                                ["wallpaper_thumb"]
                                            .toString(),
                                      ),
                                      fit: BoxFit.cover)),
                          height:
                              (MediaQuery.of(context).size.width / 2) / 0.6225 -
                                  108.5,
                          width: MediaQuery.of(context).size.width / 2 - 59)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PremiumBanner extends StatelessWidget {
  final bool comparator;
  final Widget child;
  const PremiumBanner({this.comparator, this.child});
  @override
  Widget build(BuildContext context) {
    return comparator
        ? child
        : Stack(
            children: <Widget>[
              child,
              Positioned(
                top: (MediaQuery.of(context).size.width / 2) / 0.6225 - 142,
                left: MediaQuery.of(context).size.width / 2 - 102.5,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20))),
                  padding: const EdgeInsets.all(0),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Icon(
                      JamIcons.star_f,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}

class PremiumBannerWalls extends StatelessWidget {
  final bool comparator;
  final Widget defaultChild;
  final Widget trueChild;
  const PremiumBannerWalls(
      {this.comparator, this.defaultChild, this.trueChild});
  @override
  Widget build(BuildContext context) {
    return comparator
        ? defaultChild
        : Stack(
            children: <Widget>[
              trueChild,
              Positioned(
                top: (MediaQuery.of(context).size.width / 2) / 0.6225 - 68,
                left: MediaQuery.of(context).size.width / 2 - 53.5,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20))),
                  padding: const EdgeInsets.all(0),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Icon(
                      JamIcons.star_f,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}

class PremiumBannerWallsCarousel extends StatelessWidget {
  final bool comparator;
  final Widget child;
  const PremiumBannerWallsCarousel({this.comparator, this.child});
  @override
  Widget build(BuildContext context) {
    return comparator
        ? child
        : Stack(
            children: <Widget>[
              child,
              Positioned(
                top: 160,
                left: MediaQuery.of(context).size.width * 0.8 - 50,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20))),
                  padding: const EdgeInsets.all(0),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Icon(
                      JamIcons.star_f,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}

class PremiumBannerSetup extends StatelessWidget {
  final bool comparator;
  final Widget child;
  const PremiumBannerSetup({this.comparator, this.child});
  @override
  Widget build(BuildContext context) {
    return comparator
        ? child
        : Stack(
            children: <Widget>[
              child,
              Positioned(
                top: MediaQuery.of(context).size.height * 0.62 - 32,
                left: MediaQuery.of(context).size.width * 0.642 - 15,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomRight: Radius.circular(10))),
                  padding: const EdgeInsets.all(0),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Icon(
                      JamIcons.star_f,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}

class PremiumBannerSetupOld extends StatelessWidget {
  final bool comparator;
  final Widget child;
  const PremiumBannerSetupOld({this.comparator, this.child});
  @override
  Widget build(BuildContext context) {
    return comparator
        ? child
        : Stack(
            children: <Widget>[
              child,
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomRight: Radius.circular(10))),
                  padding: const EdgeInsets.all(0),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Icon(
                      JamIcons.star_f,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}

class PremiumBannerSetupPhotographer extends StatelessWidget {
  final bool comparator;
  final Widget child;
  const PremiumBannerSetupPhotographer({this.comparator, this.child});
  @override
  Widget build(BuildContext context) {
    return comparator
        ? child
        : Stack(
            children: <Widget>[
              child,
              Positioned(
                top: (MediaQuery.of(context).size.width / 2) / 0.5025 - 52,
                left: MediaQuery.of(context).size.width / 2 - 53.5,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20))),
                  padding: const EdgeInsets.all(0),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Icon(
                      JamIcons.star_f,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}
