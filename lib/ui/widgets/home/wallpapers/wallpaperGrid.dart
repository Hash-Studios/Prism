import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/global/globals.dart' as globals;
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/config.dart' as config;

class WallpaperGrid extends StatefulWidget {
  final String provider;
  const WallpaperGrid({@required this.provider});
  @override
  _WallpaperGridState createState() => _WallpaperGridState();
}

class _WallpaperGridState extends State<WallpaperGrid>
    with TickerProviderStateMixin {
  AnimationController _controller;
  AnimationController shakeController;
  Animation<Color> animation;
  int longTapIndex;
  GlobalKey<RefreshIndicatorState> refreshHomeKey =
      GlobalKey<RefreshIndicatorState>();
  int _current = 0;
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
    Data.prismWalls = [];
    Data.subPrismWalls = [];
    Data.getPrismWalls();
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
    final CarouselController carouselController = CarouselController();
    return NestedScrollView(
        controller: controller,
        headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
              SliverAppBar(
                primary: false,
                backgroundColor: Theme.of(context).primaryColor,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                expandedHeight: 200,
                flexibleSpace: SizedBox(
                  child: Stack(
                    alignment: AlignmentDirectional.bottomEnd,
                    children: <Widget>[
                      CarouselSlider.builder(
                        carouselController: carouselController,
                        itemCount: 5,
                        options: CarouselOptions(
                            height: 200,
                            autoPlay: true,
                            autoPlayInterval: const Duration(seconds: 3),
                            onPageChanged: (index, reason) {
                              if (mounted) {
                                setState(() {
                                  _current = index;
                                });
                              }
                            }),
                        itemBuilder: (BuildContext context, int i) => i == 4
                            ? Container(
                                width: MediaQuery.of(context).size.width,
                                margin: const EdgeInsets.fromLTRB(3, 1, 3, 6),
                                child: GestureDetector(
                                  onTap: () {
                                    launch(
                                        "https://twitter.com/PrismWallpapers");
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: animation.value,
                                        borderRadius: BorderRadius.circular(20),
                                        image: const DecorationImage(
                                            image: CachedNetworkImageProvider(
                                                "https://unblast.com/wp-content/uploads/2018/08/Gradient-Mesh-21.jpg"),
                                            fit: BoxFit.cover)),
                                    child: Center(
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width,
                                        color: Colors.black.withOpacity(0.4),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "FOLLOW US ON TWITTER",
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline2
                                                .copyWith(
                                                    fontSize: 20,
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: MediaQuery.of(context).size.width,
                                margin: const EdgeInsets.fromLTRB(3, 1, 3, 6),
                                child: GestureDetector(
                                  onTap: () {
                                    if (Data.subPrismWalls == []) {
                                    } else {
                                      Navigator.pushNamed(
                                          context, wallpaperRoute,
                                          arguments: [
                                            widget.provider,
                                            i,
                                            Data.subPrismWalls[i]
                                                ["wallpaper_thumb"],
                                          ]);
                                    }
                                  },
                                  onLongPress: () {
                                    setState(() {
                                      longTapIndex = i;
                                    });
                                    shakeController.forward(from: 0.0);
                                    if (Data.subPrismWalls == []) {
                                    } else {
                                      HapticFeedback.vibrate();
                                      createDynamicLink(
                                          Data.subPrismWalls[i]["id"]
                                              .toString(),
                                          widget.provider,
                                          Data.subPrismWalls[i]["wallpaper_url"]
                                              .toString(),
                                          Data.subPrismWalls[i]
                                                  ["wallpaper_thumb"]
                                              .toString());
                                    }
                                  },
                                  child: Padding(
                                    padding: i == longTapIndex
                                        ? EdgeInsets.symmetric(
                                            vertical: offsetAnimation.value / 2,
                                            horizontal: offsetAnimation.value)
                                        : const EdgeInsets.all(0),
                                    child: Data.subPrismWalls.isEmpty
                                        ? Container(
                                            decoration: BoxDecoration(
                                              color: animation.value,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                                color: animation.value,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                image: DecorationImage(
                                                    image: CachedNetworkImageProvider(
                                                        Data.subPrismWalls[i][
                                                                "wallpaper_thumb"]
                                                            .toString()),
                                                    fit: BoxFit.cover)),
                                            child: Center(
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                    .size
                                                    .width,
                                                color: Colors.black
                                                    .withOpacity(0.4),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: Text(
                                                    globals.topTitleText[i]
                                                        .toString(),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headline2
                                                        .copyWith(
                                                            color: Colors.white,
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [0, 1, 2, 3, 4].map((i) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              width: _current == i ? 8.0 : 7.0,
                              height: _current == i ? 8.0 : 7.0,
                              margin: const EdgeInsets.symmetric(
                                  vertical: 14.0, horizontal: 2.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _current == i
                                    ? config.Colors().mainAccentColor(1)
                                    : config.Colors()
                                        .mainAccentColor(1)
                                        .withOpacity(0),
                                border: Border.all(
                                  color: _current == i
                                      ? config.Colors()
                                          .mainAccentColor(1)
                                          .withOpacity(0)
                                      : config.Colors().mainAccentColor(1),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
        body: RefreshIndicator(
          backgroundColor: Theme.of(context).primaryColor,
          key: refreshHomeKey,
          onRefresh: refreshList,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels ==
                  scrollInfo.metrics.maxScrollExtent) {
                if (!seeMoreLoader) {
                  Data.seeMorePrism();
                  setState(() {
                    seeMoreLoader = true;
                    Future.delayed(const Duration(seconds: 4))
                        .then((value) => seeMoreLoader = false);
                  });
                }
              }
              return false;
            },
            child: GridView.builder(
              physics: const ScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
              itemCount: Data.subPrismWalls.isEmpty
                  ? 20
                  : Data.subPrismWalls.length - 4,
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
                index = index + 4;
                if (index == Data.subPrismWalls.length - 1) {
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
                          Data.seeMorePrism();
                          setState(() {
                            seeMoreLoader = true;
                            Future.delayed(const Duration(seconds: 4))
                                .then((value) => seeMoreLoader = false);
                          });
                        }
                      },
                      child:
                          !seeMoreLoader ? const Text("See more") : Loader());
                }
                return FocusedMenuHolder(
                    provider: widget.provider,
                    index: index,
                    child: AnimatedBuilder(
                        animation: offsetAnimation,
                        builder: (buildContext, child) {
                          if (offsetAnimation.value < 0.0) {
                            debugPrint('${offsetAnimation.value + 8.0}');
                          }
                          return GestureDetector(
                            onTap: () {
                              if (Data.subPrismWalls == []) {
                              } else {
                                Navigator.pushNamed(context, wallpaperRoute,
                                    arguments: [
                                      widget.provider,
                                      index,
                                      Data.subPrismWalls[index]
                                          ["wallpaper_thumb"],
                                    ]);
                              }
                            },
                            onLongPress: () {
                              setState(() {
                                longTapIndex = index;
                              });
                              shakeController.forward(from: 0.0);
                              if (Data.subPrismWalls == []) {
                              } else {
                                HapticFeedback.vibrate();
                                createDynamicLink(
                                    Data.subPrismWalls[index]["id"].toString(),
                                    widget.provider,
                                    Data.subPrismWalls[index]["wallpaper_url"]
                                        .toString(),
                                    Data.subPrismWalls[index]["wallpaper_thumb"]
                                        .toString());
                              }
                            },
                            child: Padding(
                                padding: index == longTapIndex
                                    ? EdgeInsets.symmetric(
                                        vertical: offsetAnimation.value / 2,
                                        horizontal: offsetAnimation.value)
                                    : const EdgeInsets.all(0),
                                child: Container(
                                  decoration: Data.subPrismWalls.isEmpty
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
                                                  Data.subPrismWalls[index]
                                                          ["wallpaper_thumb"]
                                                      .toString()),
                                              fit: BoxFit.cover)),
                                )),
                          );
                        }));
              },
            ),
          ),
        ));
  }
}
