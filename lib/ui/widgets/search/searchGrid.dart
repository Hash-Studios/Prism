import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as wData;
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pData;
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/focussedMenu/searchFocusedMenu.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;

class SearchGrid extends StatefulWidget {
  final String query;
  final String selectedProvider;
  const SearchGrid({@required this.query, @required this.selectedProvider});
  @override
  _SearchGridState createState() => _SearchGridState();
}

class _SearchGridState extends State<SearchGrid> with TickerProviderStateMixin {
  AnimationController _controller;
  AnimationController shakeController;
  Animation<Color> animation;
  int longTapIndex;
  GlobalKey<RefreshIndicatorState> refreshHomeKey =
      GlobalKey<RefreshIndicatorState>();

  bool seeMoreLoader = false;
  @override
  void initState() {
    super.initState();
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
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
    shakeController.dispose();
    super.dispose();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    await Future.delayed(const Duration(milliseconds: 500));
    if (widget.selectedProvider == "WallHaven") {
      wData.wallsS = [];
      wData.getWallsbyQuery(widget.query, main.prefs.get('WHcategories') as int,
          main.prefs.get('WHpurity') as int);
    } else if (widget.selectedProvider == "Pexels") {
      pData.wallsPS = [];
      pData.getWallsPbyQuery(widget.query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation = Tween(begin: 0.0, end: 8.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshHomeKey,
      onRefresh: refreshList,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            if (!seeMoreLoader) {
              if (widget.selectedProvider == "WallHaven") {
                wData.getWallsbyQueryPage(
                    widget.query,
                    main.prefs.get('WHcategories') as int,
                    main.prefs.get('WHpurity') as int);
              } else if (widget.selectedProvider == "Pexels") {
                pData.getWallsPbyQueryPage(widget.query);
              }

              setState(() {
                seeMoreLoader = true;
                Future.delayed(const Duration(seconds: 2))
                    .then((value) => seeMoreLoader = false);
              });
            }
          }
          return false;
        },
        child: GridView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          itemCount: widget.selectedProvider == "WallHaven"
              ? wData.wallsS.isEmpty
                  ? 24
                  : wData.wallsS.length
              : pData.wallsPS.isEmpty
                  ? 24
                  : pData.wallsPS.length,
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent:
                  MediaQuery.of(context).orientation == Orientation.portrait
                      ? 300
                      : 250,
              childAspectRatio: 0.6625,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8),
          itemBuilder: (context, index) {
            if (widget.selectedProvider == "WallHaven") {
              if (index == wData.wallsS.length - 1 && index >= 23) {
                return FlatButton(
                    color: Provider.of<ThemeModel>(context, listen: false)
                                .returnThemeType() ==
                            "Dark"
                        ? Colors.white10
                        : Colors.black.withOpacity(.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      if (!seeMoreLoader) {
                        wData.getWallsbyQueryPage(
                            widget.query,
                            main.prefs.get('WHcategories') as int,
                            main.prefs.get('WHpurity') as int);
                        setState(() {
                          seeMoreLoader = true;
                          Future.delayed(const Duration(seconds: 2))
                              .then((value) => seeMoreLoader = false);
                        });
                      }
                    },
                    child: !seeMoreLoader ? const Text("See more") : Loader());
              }
            } else if (widget.selectedProvider == "Pexels") {
              if (index == pData.wallsPS.length - 1 && index >= 23) {
                return FlatButton(
                    color: Provider.of<ThemeModel>(context, listen: false)
                                .returnThemeType() ==
                            "Dark"
                        ? Colors.white10
                        : Colors.black.withOpacity(.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      if (!seeMoreLoader) {
                        pData.getWallsPbyQueryPage(widget.query);
                        setState(() {
                          seeMoreLoader = true;
                          Future.delayed(const Duration(seconds: 2))
                              .then((value) => seeMoreLoader = false);
                        });
                      }
                    },
                    child: !seeMoreLoader ? const Text("See more") : Loader());
              }
            }

            return SearchFocusedMenuHolder(
                selectedProvider: widget.selectedProvider,
                query: widget.query,
                index: index,
                child: AnimatedBuilder(
                    animation: offsetAnimation,
                    builder: (buildContext, child) {
                      if (offsetAnimation.value < 0.0) {
                        debugPrint('${offsetAnimation.value + 8.0}');
                      }
                      return Padding(
                        padding: index == longTapIndex
                            ? EdgeInsets.symmetric(
                                vertical: offsetAnimation.value / 2,
                                horizontal: offsetAnimation.value)
                            : const EdgeInsets.all(0),
                        child: Stack(
                          children: [
                            Container(
                              decoration: widget.selectedProvider == "WallHaven"
                                  ? wData.wallsS.isEmpty
                                      ? BoxDecoration(
                                          color: animation.value,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        )
                                      : BoxDecoration(
                                          color: animation.value,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          image: DecorationImage(
                                              image: CachedNetworkImageProvider(
                                                  wData.wallsS[index]
                                                      .thumbs["original"]
                                                      .toString()),
                                              fit: BoxFit.cover))
                                  : pData.wallsPS.isEmpty
                                      ? BoxDecoration(
                                          color: animation.value,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        )
                                      : BoxDecoration(
                                          color: animation.value,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          image: DecorationImage(
                                              image: CachedNetworkImageProvider(
                                                  pData.wallsPS[index]
                                                      .src["medium"]
                                                      .toString()),
                                              fit: BoxFit.cover)),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  splashColor: Theme.of(context)
                                      .accentColor
                                      .withOpacity(0.3),
                                  highlightColor: Theme.of(context)
                                      .accentColor
                                      .withOpacity(0.1),
                                  onTap: () {
                                    if (widget.selectedProvider ==
                                        "WallHaven") {
                                      if (wData.wallsS == []) {
                                      } else {
                                        Navigator.pushNamed(
                                            context, wallpaperRoute,
                                            arguments: [
                                              widget.query,
                                              index,
                                              wData.wallsS[index]
                                                  .thumbs["small"],
                                            ]);
                                      }
                                    } else if (widget.selectedProvider ==
                                        "Pexels") {
                                      if (pData.wallsPS == []) {
                                      } else {
                                        Navigator.pushNamed(
                                            context, searchWallpaperRoute,
                                            arguments: [
                                              widget.selectedProvider,
                                              widget.query,
                                              index,
                                              pData
                                                  .wallsPS[index].src["medium"],
                                            ]);
                                      }
                                    }
                                  },
                                  onLongPress: () {
                                    setState(() {
                                      longTapIndex = index;
                                    });
                                    shakeController.forward(from: 0.0);
                                    if (widget.selectedProvider ==
                                        "WallHaven") {
                                      if (wData.wallsS == []) {
                                      } else {
                                        HapticFeedback.vibrate();
                                        createDynamicLink(
                                            wData.wallsS[index].id,
                                            "WallHaven",
                                            wData.wallsS[index].path,
                                            wData.wallsS[index]
                                                .thumbs["original"]
                                                .toString());
                                      }
                                    } else if (widget.selectedProvider ==
                                        "Pexels") {
                                      if (wData.wallsS == []) {
                                      } else {
                                        HapticFeedback.vibrate();
                                        createDynamicLink(
                                            pData.wallsPS[index].id,
                                            "Pexels",
                                            pData.wallsPS[index].src["original"]
                                                .toString(),
                                            pData.wallsPS[index].src["medium"]
                                                .toString());
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }));
          },
        ),
      ),
    );
  }
}
