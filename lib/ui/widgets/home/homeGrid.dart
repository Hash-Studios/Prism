import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/prism/provider/prismProvider.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/global/globals.dart' as globals;

class HomeGrid extends StatefulWidget {
  final String provider;
  HomeGrid({@required this.provider});
  @override
  _HomeGridState createState() => _HomeGridState();
}

class _HomeGridState extends State<HomeGrid> with TickerProviderStateMixin {
  AnimationController _controller;
  AnimationController shakeController;
  Animation<Color> animation;
  int longTapIndex;
  var refreshHomeKey = GlobalKey<RefreshIndicatorState>();

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
    animation = Provider.of<ThemeModel>(context, listen: false).returnTheme() ==
            ThemeType.Dark
        ? TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.white10,
                  end: Colors.white12,
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.white12,
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
    shakeController.dispose();
    super.dispose();
  }

  Future<Null> refreshList() async {
    refreshHomeKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(milliseconds: 500));
    if (widget.provider == "WallHaven") {
      Provider.of<WallHavenProvider>(context, listen: false).walls = [];
      Provider.of<WallHavenProvider>(context, listen: false).getData();
    } else if (widget.provider == "Pexels") {
      Provider.of<PexelsProvider>(context, listen: false).wallsP = [];
      switch (Provider.of<CategoryProvider>(context, listen: false)
          .selectedCategory) {
        case "Curated":
          Provider.of<PexelsProvider>(context, listen: false).getDataP();
          break;
        case "Abstract":
          Provider.of<PexelsProvider>(context, listen: false)
            ..getAbstractWalls();
          break;
        case "Nature":
          Provider.of<PexelsProvider>(context, listen: false).getNatureWalls();
          break;
        case "Art":
          Provider.of<PexelsProvider>(context, listen: false).getArtWalls();
          break;
        case "Minimal":
          Provider.of<PexelsProvider>(context, listen: false).getMinimalWalls();
          break;
        case "Textures":
          Provider.of<PexelsProvider>(context, listen: false)
              .getTexturesWalls();
          break;
        case "MOnochrome":
          Provider.of<PexelsProvider>(context, listen: false)
              .getMonochromeWalls();
          break;
        case "Space":
          Provider.of<PexelsProvider>(context, listen: false).getSpaceWalls();
          break;
        case "Animals":
          Provider.of<PexelsProvider>(context, listen: false).getAnimalsWalls();
          break;
        case "Neon":
          Provider.of<PexelsProvider>(context, listen: false).getNeonWalls();
          break;
        case "Sports":
          Provider.of<PexelsProvider>(context, listen: false).getSportsWalls();
          break;
        case "Music":
          Provider.of<PexelsProvider>(context, listen: false).getMusicWalls();
          break;
        default:
          break;
      }
    } else if (widget.provider == "Prism") {
      Provider.of<PrismProvider>(context, listen: false).prismWalls = [];
      Provider.of<PrismProvider>(context, listen: false).subPrismWalls = [];
      Provider.of<PrismProvider>(context, listen: false).getPrismWalls();
    } else if (widget.provider.length > 6 &&
        widget.provider.substring(0, 6) == "Colors") {
      Provider.of<PexelsProvider>(context, listen: false).wallsC = [];
      Provider.of<PexelsProvider>(context, listen: false)
          .getWallsPbyColorPage(widget.provider.substring(9));
    } else {
      Provider.of<WallHavenProvider>(context, listen: false).wallsS = [];
      Provider.of<WallHavenProvider>(context, listen: false)
          .getWallsbyQuery(widget.provider);
    }
    return null;
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
            if (widget.provider == "WallHaven") {
              if (!seeMoreLoader) {
                Provider.of<WallHavenProvider>(context, listen: false)
                    .getData();
                setState(() {
                  seeMoreLoader = true;
                  Future.delayed(Duration(seconds: 4))
                      .then((value) => seeMoreLoader = false);
                });
              }
            } else if (widget.provider == "Prism") {
              if (!seeMoreLoader) {
                Provider.of<PrismProvider>(context, listen: false)
                    .seeMorePrism();
                setState(() {
                  seeMoreLoader = true;
                  Future.delayed(Duration(seconds: 4))
                      .then((value) => seeMoreLoader = false);
                });
              }
            } else if (widget.provider == "Pexels") {
              if (!seeMoreLoader) {
                switch (Provider.of<CategoryProvider>(context, listen: false)
                    .selectedCategory) {
                  case "Curated":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getDataP();
                    break;
                  case "Abstract":
                    Provider.of<PexelsProvider>(context, listen: false)
                      ..getAbstractWalls();
                    break;
                  case "Nature":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getNatureWalls();
                    break;
                  case "Art":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getArtWalls();
                    break;
                  case "Minimal":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getMinimalWalls();
                    break;
                  case "Textures":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getTexturesWalls();
                    break;
                  case "MOnochrome":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getMonochromeWalls();
                    break;
                  case "Space":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getSpaceWalls();
                    break;
                  case "Animals":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getAnimalsWalls();
                    break;
                  case "Neon":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getNeonWalls();
                    break;
                  case "Sports":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getSportsWalls();
                    break;
                  case "Music":
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getMusicWalls();
                    break;
                  default:
                    break;
                }
                setState(() {
                  seeMoreLoader = true;
                  Future.delayed(Duration(seconds: 4))
                      .then((value) => seeMoreLoader = false);
                });
              }
            } else if (widget.provider.length > 6 &&
                widget.provider.substring(0, 6) == "Colors") {
              if (!seeMoreLoader) {
                Provider.of<PexelsProvider>(context, listen: false)
                    .getWallsPbyColorPage(widget.provider.substring(9));
                setState(() {
                  seeMoreLoader = true;
                  Future.delayed(Duration(seconds: 4))
                      .then((value) => seeMoreLoader = false);
                });
              }
            } else {
              if (!seeMoreLoader) {
                Provider.of<WallHavenProvider>(context, listen: false)
                    .getWallsbyQueryPage(widget.provider);
                setState(() {
                  seeMoreLoader = true;
                  Future.delayed(Duration(seconds: 4))
                      .then((value) => seeMoreLoader = false);
                });
              }
            }
          }
        },
        child: GridView.builder(
          key: globals.keyHomeWallpaperList,
          controller: controller,
          padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
          itemCount: widget.provider == "WallHaven"
              ? Provider.of<WallHavenProvider>(context).walls.length == 0
                  ? 24
                  : Provider.of<WallHavenProvider>(context).walls.length
              : widget.provider == "Prism"
                  ? Provider.of<PrismProvider>(context).subPrismWalls.length ==
                          0
                      ? 24
                      : Provider.of<PrismProvider>(context).subPrismWalls.length
                  : widget.provider == "Pexels"
                      ? Provider.of<PexelsProvider>(context).wallsP.length == 0
                          ? 24
                          : Provider.of<PexelsProvider>(context).wallsP.length
                      : widget.provider.length > 6 &&
                              widget.provider.substring(0, 6) == "Colors"
                          ? Provider.of<PexelsProvider>(context)
                                      .wallsC
                                      .length ==
                                  0
                              ? 24
                              : Provider.of<PexelsProvider>(context)
                                  .wallsC
                                  .length
                          : Provider.of<WallHavenProvider>(context)
                                      .wallsS
                                      .length ==
                                  0
                              ? 24
                              : Provider.of<WallHavenProvider>(context)
                                  .wallsS
                                  .length,
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
            if (widget.provider == "WallHaven") {
              if (index ==
                  Provider.of<WallHavenProvider>(context).walls.length - 1) {
                return FlatButton(
                    color: Provider.of<ThemeModel>(context, listen: false)
                                .returnTheme() ==
                            ThemeType.Dark
                        ? Colors.white10
                        : Colors.black.withOpacity(.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      if (!seeMoreLoader) {
                        Provider.of<WallHavenProvider>(context, listen: false)
                            .getData();
                        setState(() {
                          seeMoreLoader = true;
                          Future.delayed(Duration(seconds: 4))
                              .then((value) => seeMoreLoader = false);
                        });
                      }
                    },
                    child: !seeMoreLoader ? Text("See more") : Loader());
              }
            } else if (widget.provider == "Prism") {
              if (index ==
                  Provider.of<PrismProvider>(context).subPrismWalls.length -
                      1) {
                return FlatButton(
                    color: Provider.of<ThemeModel>(context, listen: false)
                                .returnTheme() ==
                            ThemeType.Dark
                        ? Colors.white10
                        : Colors.black.withOpacity(.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      if (!seeMoreLoader) {
                        Provider.of<PrismProvider>(context, listen: false)
                            .seeMorePrism();
                        setState(() {
                          seeMoreLoader = true;
                          Future.delayed(Duration(seconds: 4))
                              .then((value) => seeMoreLoader = false);
                        });
                      }
                    },
                    child: !seeMoreLoader ? Text("See more") : Loader());
              }
            } else if (widget.provider == "Pexels") {
              if (index ==
                  Provider.of<PexelsProvider>(context).wallsP.length - 1) {
                return FlatButton(
                    color: Provider.of<ThemeModel>(context, listen: false)
                                .returnTheme() ==
                            ThemeType.Dark
                        ? Colors.white10
                        : Colors.black.withOpacity(.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      if (!seeMoreLoader) {
                        switch (Provider.of<CategoryProvider>(context,
                                listen: false)
                            .selectedCategory) {
                          case "Curated":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getDataP();
                            break;
                          case "Abstract":
                            Provider.of<PexelsProvider>(context, listen: false)
                              ..getAbstractWalls();
                            break;
                          case "Nature":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getNatureWalls();
                            break;
                          case "Art":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getArtWalls();
                            break;
                          case "Minimal":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getMinimalWalls();
                            break;
                          case "Textures":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getTexturesWalls();
                            break;
                          case "MOnochrome":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getMonochromeWalls();
                            break;
                          case "Space":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getSpaceWalls();
                            break;
                          case "Animals":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getAnimalsWalls();
                            break;
                          case "Neon":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getNeonWalls();
                            break;
                          case "Sports":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getSportsWalls();
                            break;
                          case "Music":
                            Provider.of<PexelsProvider>(context, listen: false)
                                .getMusicWalls();
                            break;
                          default:
                            break;
                        }
                        setState(() {
                          seeMoreLoader = true;
                          Future.delayed(Duration(seconds: 4))
                              .then((value) => seeMoreLoader = false);
                        });
                      }
                    },
                    child: !seeMoreLoader ? Text("See more") : Loader());
              }
            } else if (widget.provider.length > 6 &&
                widget.provider.substring(0, 6) == "Colors") {
              if (index ==
                  Provider.of<PexelsProvider>(context).wallsC.length - 1) {
                return FlatButton(
                    color: Provider.of<ThemeModel>(context, listen: false)
                                .returnTheme() ==
                            ThemeType.Dark
                        ? Colors.white10
                        : Colors.black.withOpacity(.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      if (!seeMoreLoader) {
                        Provider.of<PexelsProvider>(context, listen: false)
                            .getWallsPbyColorPage(widget.provider.substring(9));
                        setState(() {
                          seeMoreLoader = true;
                          Future.delayed(Duration(seconds: 4))
                              .then((value) => seeMoreLoader = false);
                        });
                      }
                    },
                    child: !seeMoreLoader ? Text("See more") : Loader());
              }
            } else {
              if (index ==
                      Provider.of<WallHavenProvider>(context).wallsS.length -
                          1 &&
                  index >= 23) {
                return FlatButton(
                    color: Provider.of<ThemeModel>(context, listen: false)
                                .returnTheme() ==
                            ThemeType.Dark
                        ? Colors.white10
                        : Colors.black.withOpacity(.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      if (!seeMoreLoader) {
                        Provider.of<WallHavenProvider>(context, listen: false)
                            .getWallsbyQueryPage(widget.provider);
                        setState(() {
                          seeMoreLoader = true;
                          Future.delayed(Duration(seconds: 4))
                              .then((value) => seeMoreLoader = false);
                        });
                      }
                    },
                    child: !seeMoreLoader ? Text("See more") : Loader());
              }
            }
            return FocusedMenuHolder(
                provider: widget.provider,
                index: index,
                child: AnimatedBuilder(
                    animation: offsetAnimation,
                    builder: (buildContext, child) {
                      if (offsetAnimation.value < 0.0)
                        print('${offsetAnimation.value + 8.0}');
                      return GestureDetector(
                        child: Padding(
                          padding: index == longTapIndex
                              ? EdgeInsets.symmetric(
                                  vertical: offsetAnimation.value / 2,
                                  horizontal: offsetAnimation.value)
                              : EdgeInsets.all(0),
                          child: Container(
                            decoration: widget.provider == "WallHaven"
                                ? Provider.of<WallHavenProvider>(context).walls.length ==
                                        0
                                    ? BoxDecoration(
                                        color: animation.value,
                                        borderRadius: BorderRadius.circular(20),
                                      )
                                    : BoxDecoration(
                                        color: animation.value,
                                        borderRadius: BorderRadius.circular(20),
                                        image: DecorationImage(
                                            image: NetworkImage(
                                                Provider.of<WallHavenProvider>(context)
                                                    .walls[index]
                                                    .thumbs["original"]),
                                            fit: BoxFit.cover))
                                : widget.provider == "Prism"
                                    ? Provider.of<PrismProvider>(context).subPrismWalls.length ==
                                            0
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
                                                image: NetworkImage(Provider.of<PrismProvider>(context)
                                                        .subPrismWalls[index]
                                                    ["wallpaper_thumb"]),
                                                fit: BoxFit.cover))
                                    : widget.provider == "Pexels"
                                        ? Provider.of<PexelsProvider>(context).wallsP.length ==
                                                0
                                            ? BoxDecoration(
                                                color: animation.value,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              )
                                            : BoxDecoration(
                                                color: animation.value,
                                                borderRadius: BorderRadius.circular(20),
                                                image: DecorationImage(image: NetworkImage(Provider.of<PexelsProvider>(context).wallsP[index].src["medium"]), fit: BoxFit.cover))
                                        : widget.provider.length > 6 && widget.provider.substring(0, 6) == "Colors"
                                            ? Provider.of<PexelsProvider>(context).wallsC.length == 0
                                                ? BoxDecoration(
                                                    color: animation.value,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  )
                                                : BoxDecoration(color: animation.value, borderRadius: BorderRadius.circular(20), image: DecorationImage(image: NetworkImage(Provider.of<PexelsProvider>(context).wallsC[index].src["medium"]), fit: BoxFit.cover))
                                            : Provider.of<WallHavenProvider>(context).wallsS.length == 0
                                                ? BoxDecoration(
                                                    color: animation.value,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  )
                                                : BoxDecoration(color: animation.value, borderRadius: BorderRadius.circular(20), image: DecorationImage(image: NetworkImage(Provider.of<WallHavenProvider>(context).wallsS[index].thumbs["original"]), fit: BoxFit.cover)),
                          ),
                        ),
                        onTap: () {
                          if (widget.provider == "WallHaven") {
                            if (Provider.of<WallHavenProvider>(context,
                                        listen: false)
                                    .walls ==
                                []) {
                            } else {
                              Navigator.pushNamed(context, WallpaperRoute,
                                  arguments: [
                                    widget.provider,
                                    index,
                                    Provider.of<WallHavenProvider>(context,
                                            listen: false)
                                        .walls[index]
                                        .thumbs["small"],
                                  ]);
                            }
                          } else if (widget.provider == "Prism") {
                            if (Provider.of<PrismProvider>(context,
                                        listen: false)
                                    .subPrismWalls ==
                                []) {
                            } else {
                              Navigator.pushNamed(context, WallpaperRoute,
                                  arguments: [
                                    widget.provider,
                                    index,
                                    Provider.of<PrismProvider>(context,
                                                listen: false)
                                            .subPrismWalls[index]
                                        ["wallpaper_thumb"],
                                  ]);
                            }
                          } else if (widget.provider == "Pexels") {
                            if (Provider.of<PexelsProvider>(context,
                                        listen: false)
                                    .wallsP ==
                                []) {
                            } else {
                              Navigator.pushNamed(context, WallpaperRoute,
                                  arguments: [
                                    widget.provider,
                                    index,
                                    Provider.of<PexelsProvider>(context,
                                            listen: false)
                                        .wallsP[index]
                                        .src["small"]
                                  ]);
                            }
                          } else if (widget.provider.length > 6 &&
                              widget.provider.substring(0, 6) == "Colors") {
                            if (Provider.of<PexelsProvider>(context,
                                        listen: false)
                                    .wallsC ==
                                []) {
                            } else {
                              Navigator.pushNamed(context, WallpaperRoute,
                                  arguments: [
                                    widget.provider,
                                    index,
                                    Provider.of<PexelsProvider>(context,
                                            listen: false)
                                        .wallsC[index]
                                        .src["small"]
                                  ]);
                            }
                          } else {
                            if (Provider.of<WallHavenProvider>(context,
                                        listen: false)
                                    .wallsS ==
                                []) {
                            } else {
                              Navigator.pushNamed(context, WallpaperRoute,
                                  arguments: [
                                    widget.provider,
                                    index,
                                    Provider.of<WallHavenProvider>(context,
                                            listen: false)
                                        .wallsS[index]
                                        .thumbs["small"],
                                  ]);
                            }
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            longTapIndex = index;
                          });
                          shakeController.forward(from: 0.0);
                          if (widget.provider == "WallHaven") {
                            if (Provider.of<WallHavenProvider>(context,
                                        listen: false)
                                    .walls ==
                                []) {
                            } else {
                              HapticFeedback.vibrate();
                              createDynamicLink(
                                  Provider.of<WallHavenProvider>(context,
                                          listen: false)
                                      .walls[index]
                                      .id,
                                  widget.provider,
                                  Provider.of<WallHavenProvider>(context,
                                          listen: false)
                                      .walls[index]
                                      .path,
                                  Provider.of<WallHavenProvider>(context,
                                          listen: false)
                                      .walls[index]
                                      .thumbs["original"]);
                            }
                          } else if (widget.provider == "Prism") {
                            if (Provider.of<PrismProvider>(context,
                                        listen: false)
                                    .subPrismWalls ==
                                []) {
                            } else {
                              HapticFeedback.vibrate();
                              createDynamicLink(
                                  Provider.of<PrismProvider>(context,
                                          listen: false)
                                      .subPrismWalls[index]["id"],
                                  widget.provider,
                                  Provider.of<PrismProvider>(context,
                                          listen: false)
                                      .subPrismWalls[index]["wallpaper_url"],
                                  Provider.of<PrismProvider>(context,
                                          listen: false)
                                      .subPrismWalls[index]["wallpaper_thumb"]);
                            }
                          } else if (widget.provider == "Pexels") {
                            if (Provider.of<PexelsProvider>(context,
                                        listen: false)
                                    .wallsP ==
                                []) {
                            } else {
                              HapticFeedback.vibrate();
                              createDynamicLink(
                                  Provider.of<PexelsProvider>(context,
                                          listen: false)
                                      .wallsP[index]
                                      .id,
                                  widget.provider,
                                  Provider.of<PexelsProvider>(context,
                                          listen: false)
                                      .wallsP[index]
                                      .src["original"],
                                  Provider.of<PexelsProvider>(context,
                                          listen: false)
                                      .wallsP[index]
                                      .src["medium"]);
                            }
                          } else if (widget.provider.length > 6 &&
                              widget.provider.substring(0, 6) == "Colors") {
                            if (Provider.of<PexelsProvider>(context,
                                        listen: false)
                                    .wallsC ==
                                []) {
                            } else {
                              HapticFeedback.vibrate();
                              createDynamicLink(
                                  Provider.of<PexelsProvider>(context,
                                          listen: false)
                                      .wallsC[index]
                                      .id,
                                  "Pexels",
                                  Provider.of<PexelsProvider>(context,
                                          listen: false)
                                      .wallsC[index]
                                      .src["original"],
                                  Provider.of<PexelsProvider>(context,
                                          listen: false)
                                      .wallsC[index]
                                      .src["medium"]);
                            }
                          } else {
                            if (Provider.of<WallHavenProvider>(context,
                                        listen: false)
                                    .wallsS ==
                                []) {
                            } else {
                              HapticFeedback.vibrate();
                              createDynamicLink(
                                  Provider.of<WallHavenProvider>(context,
                                          listen: false)
                                      .wallsS[index]
                                      .id,
                                  "WallHaven",
                                  Provider.of<WallHavenProvider>(context,
                                          listen: false)
                                      .wallsS[index]
                                      .path,
                                  Provider.of<WallHavenProvider>(context,
                                          listen: false)
                                      .wallsS[index]
                                      .thumbs["original"]);
                            }
                          }
                        },
                      );
                    }));
          },
        ),
      ),
    );
  }

  void createDynamicLink(
      String id, String provider, String url, String thumbUrl) async {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
        socialMetaTagParameters: SocialMetaTagParameters(
            title: "Prism Wallpapers - $id",
            imageUrl: Uri.parse(thumbUrl),
            description:
                "Check out this amazing wallpaper I got, from Prism Wallpapers App."),
        dynamicLinkParametersOptions: DynamicLinkParametersOptions(
            shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short),
        uriPrefix: 'https://prismwallpapers.page.link',
        link: Uri.parse(
            'http://prism.hash.com/share?id=$id&provider=$provider&url=$url&thumb=$thumbUrl'),
        androidParameters: AndroidParameters(
          packageName: 'com.hash.prism',
          minimumVersion: 1,
        ),
        iosParameters: IosParameters(
          bundleId: 'com.hash.prism',
          minimumVersion: '1.0.1',
          appStoreId: '1405860595',
        ));
    final ShortDynamicLink shortDynamicLink = await parameters.buildShortLink();
    final Uri shortUrl = shortDynamicLink.shortUrl;
    Clipboard.setData(
        ClipboardData(text: "🔥Check this out ➜ " + shortUrl.toString()));
    analytics.logShare(contentType: 'focussedMenu', itemId: id, method: 'link');
    toasts.shareWall();
    print(shortUrl);
  }
}
