import 'dart:math';

import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:Prism/ui/widgets/premiumBanners/premiumBanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  AnimationController? _controller;
  late Animation<Color?> animation;
  bool? isLoggedin;
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
    animation = Provider.of<ThemeModeExtended>(context, listen: false)
                .getCurrentModeStyle(
                    SchedulerBinding.instance!.window.platformBrightness) ==
            "Dark"
        ? TweenSequence<Color?>(
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
          ).animate(_controller!)
        : TweenSequence<Color?>(
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
          ).animate(_controller!)
      ..addListener(() {
        setState(() {});
      });
    _controller!.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void showPremiumPopUp(Function func) {
    if (globals.prismUser.premium == false) {
      Navigator.pushNamed(context, premiumRoute);
    } else {
      func();
    }
  }

  Future<void> checkSignIn() async {
    setState(() {
      isLoggedin = globals.prismUser.loggedIn;
    });
  }

  void showGooglePopUp(Function func) {
    debugPrint(globals.prismUser.loggedIn.toString());
    if (globals.prismUser.loggedIn == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  Future<void> refreshList() async {
    refreshKey.currentState?.show();
    CData.getCollections();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller =
        InheritedDataProvider.of(context)!.scrollController;
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshKey,
      onRefresh: refreshList,
      child: GridView.builder(
        controller: controller,
        physics: const ScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
        itemCount: CData.collections!.length,
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6225,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              if (CData.collections![index]['premium'] == false) {
                Navigator.pushNamed(
                  context,
                  collectionViewRoute,
                  arguments: [
                    CData.collections![index]['name']
                        .toString()
                        .trim()
                        .toLowerCase()
                  ],
                );
              } else {
                if (globals.prismUser.premium == true) {
                  Navigator.pushNamed(
                    context,
                    collectionViewRoute,
                    arguments: [
                      CData.collections![index]['name']
                          .toString()
                          .trim()
                          .toLowerCase()
                    ],
                  );
                } else {
                  showGooglePopUp(() {
                    showPremiumPopUp(() {
                      main.RestartWidget.restartApp(context);
                    });
                  });
                }
              }
            },
            child: PremiumBanner(
              comparator: CData.collections![index]['premium'] == false,
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
                                    color: Provider.of<ThemeModeExtended>(
                                                    context)
                                                .getCurrentModeStyle(
                                                    MediaQuery.of(context)
                                                        .platformBrightness) ==
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
                      child: CData.collections!.toList().isNotEmpty
                          ? Text(
                              CData.collections![index]['name']
                                  .toString()
                                  .toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .headline2!
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
                                  .headline2!
                                  .copyWith(
                                      fontSize: 16,
                                      color: Provider.of<ThemeModeExtended>(
                                                      context)
                                                  .getCurrentModeStyle(
                                                      MediaQuery.of(context)
                                                          .platformBrightness) ==
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
                                    color: Provider.of<ThemeModeExtended>(
                                                    context)
                                                .getCurrentModeStyle(
                                                    MediaQuery.of(context)
                                                        .platformBrightness) ==
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
                          decoration: CData.collections!.isEmpty
                              ? BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        CData.collections![index]['thumb2']
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
                                    color: Provider.of<ThemeModeExtended>(
                                                    context)
                                                .getCurrentModeStyle(
                                                    MediaQuery.of(context)
                                                        .platformBrightness) ==
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
                          decoration: CData.collections!.isEmpty
                              ? BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        CData.collections![index]['thumb1']
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
