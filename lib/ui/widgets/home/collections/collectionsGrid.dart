import 'dart:math';

import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/theme.dart';
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
  var refreshKey = GlobalKey<RefreshIndicatorState>();
  var r = Random();

  @override
  void initState() {
    checkSignIn();
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = Provider.of<ThemeModel>(context, listen: false).returnTheme() ==
            ThemeType.Dark
        ? TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.white10,
                  end: Color(0x22FFFFFF),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Color(0x22FFFFFF),
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
  dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void showPremiumPopUp(Function func) {
    if (!main.prefs.get("premium")) {
      Navigator.pushNamed(context, PremiumRoute);
    } else {
      func();
    }
  }

  void checkSignIn() async {
    setState(() {
      isLoggedin = main.prefs.get("isLoggedin");
    });
  }

  void showGooglePopUp(Function func) {
    debugPrint(main.prefs.get("isLoggedin"));
    if (!main.prefs.get("isLoggedin")) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  Future<Null> refreshList() async {
    refreshKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(milliseconds: 500));
    CData.wallpapersForCollections = [];
    CData.collectionNames = {};
    CData.collections = {};
    CData.getCollections();
    return null;
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
        physics: ScrollPhysics(),
        padding: EdgeInsets.fromLTRB(5, 0, 5, 4),
        itemCount: CData.collectionNames.length == 0
            ? 11
            : CData.collectionNames.length,
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
            child: PremiumBanner(
              comparator: globals.premiumCollections.indexOf(
                      CData.collectionNames.length == 0
                          ? "none"
                          : CData.collectionNames.toList()[index]) ==
                  -1,
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
                                    offset: Offset(5, 5),
                                    color: Provider.of<ThemeModel>(context)
                                                .currentTheme ==
                                            kLightTheme
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
                      child: CData.collectionNames.toList().length != 0
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
                                      color: Provider.of<ThemeModel>(context)
                                                  .currentTheme ==
                                              kLightTheme
                                          ? Colors.black
                                          : Colors.white,
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
                                                  .currentTheme ==
                                              kLightTheme
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
                                    offset: Offset(5, 5),
                                    color: Provider.of<ThemeModel>(context)
                                                .currentTheme ==
                                            kLightTheme
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
                          decoration: CData.collectionNames.length == 0
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
                                                ["wallpaper_thumb"],
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
                                                ["wallpaper_thumb"],
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
                                    offset: Offset(5, 5),
                                    color: Provider.of<ThemeModel>(context)
                                                .currentTheme ==
                                            kLightTheme
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
                          decoration: CData.collectionNames.length == 0
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
                                            .toString()][0]["wallpaper_thumb"],
                                      ),
                                      fit: BoxFit.cover)),
                          height:
                              (MediaQuery.of(context).size.width / 2) / 0.6225 -
                                  108.5,
                          width: MediaQuery.of(context).size.width / 2 - 59)),
                ],
              ),
            ),
            onTap: () {
              if (CData.collections == {}) {
              } else {
                if (globals.premiumCollections
                        .indexOf(CData.collectionNames.toList()[index]) ==
                    -1) {
                  Navigator.pushNamed(context, CollectionViewRoute, arguments: [
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
                        .pushNamed(context, CollectionViewRoute, arguments: [
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
          );
        },
      ),
    );
  }
}

class PremiumBanner extends StatelessWidget {
  final bool comparator;
  final Widget child;
  PremiumBanner({this.comparator, this.child});
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
                  decoration: BoxDecoration(
                      color: Color(0xFFFFB800),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20))),
                  padding: EdgeInsets.all(0),
                  child: Padding(
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
