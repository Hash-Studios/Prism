import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/theme/thumbModel.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/global/globals.dart' as globals;
import 'package:url_launcher/url_launcher.dart';

class WallpaperGrid extends StatefulWidget {
  final String provider;
  WallpaperGrid({@required this.provider});
  @override
  _WallpaperGridState createState() => _WallpaperGridState();
}

class _WallpaperGridState extends State<WallpaperGrid>
    with TickerProviderStateMixin {
  AnimationController _controller;
  AnimationController shakeController;
  Animation<Color> animation;
  int longTapIndex;
  var refreshHomeKey = GlobalKey<RefreshIndicatorState>();
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
    shakeController.dispose();
    super.dispose();
  }

  Future<Null> refreshList() async {
    refreshHomeKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(milliseconds: 500));
    Data.prismWalls = [];
    Data.subPrismWalls = [];
    Data.getPrismWalls();
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
    final CarouselController carouselController = CarouselController();
    return NestedScrollView(
        controller: controller,
        headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
              SliverAppBar(
                backgroundColor: Theme.of(context).primaryColor,
                automaticallyImplyLeading: false,
                pinned: false,
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
                            pauseAutoPlayOnTouch: true,
                            height: 200,
                            viewportFraction: 0.8,
                            initialPage: 0,
                            enableInfiniteScroll: true,
                            autoPlay: true,
                            autoPlayInterval: Duration(seconds: 3),
                            autoPlayAnimationDuration:
                                Duration(milliseconds: 800),
                            autoPlayCurve: Curves.fastOutSlowIn,
                            scrollDirection: Axis.horizontal,
                            onPageChanged: (index, reason) {
                              if (mounted)
                                setState(() {
                                  _current = index;
                                });
                            }),
                        itemBuilder: (BuildContext context, int i) => i == 4
                            ? Container(
                                width: MediaQuery.of(context).size.width,
                                margin: EdgeInsets.fromLTRB(3, 1, 3, 6),
                                child: GestureDetector(
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: animation.value,
                                        borderRadius: BorderRadius.circular(20),
                                        image: DecorationImage(
                                            image: CachedNetworkImageProvider(
                                                "https://image.freepik.com/free-vector/abstract-gradient-background-with-fluid-shapes_47641-19.jpg"),
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
                                  onTap: () {
                                    launch(
                                        "https://twitter.com/PrismWallpapers");
                                  },
                                ),
                              )
                            : Container(
                                width: MediaQuery.of(context).size.width,
                                margin: EdgeInsets.fromLTRB(3, 1, 3, 6),
                                child: GestureDetector(
                                  child: Padding(
                                    padding: i == longTapIndex
                                        ? EdgeInsets.symmetric(
                                            vertical: offsetAnimation.value / 2,
                                            horizontal: offsetAnimation.value)
                                        : EdgeInsets.all(0),
                                    child: Data.subPrismWalls.length == 0
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
                                                        Provider.of<ThumbModel>(
                                                                        context,
                                                                        listen:
                                                                            false)
                                                                    .thumbType ==
                                                                ThumbType.High
                                                            ? Data.subPrismWalls[
                                                                    i][
                                                                "wallpaper_url"]
                                                            : Data.subPrismWalls[i]
                                                                ["wallpaper_thumb"]),
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
                                                    globals.topTitleText[i],
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
                                  onTap: () {
                                    if (Data.subPrismWalls == []) {
                                    } else {
                                      Navigator.pushNamed(
                                          context, WallpaperRoute,
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
                                          Data.subPrismWalls[i]["id"],
                                          widget.provider,
                                          Data.subPrismWalls[i]
                                              ["wallpaper_url"],
                                          Data.subPrismWalls[i]
                                              ["wallpaper_thumb"]);
                                    }
                                  },
                                ),
                              ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [0, 1, 2, 3, 4].map((i) {
                              return Container(
                                width: 8.0,
                                height: 8.0,
                                margin: EdgeInsets.symmetric(
                                    vertical: 14.0, horizontal: 2.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _current == i
                                      ? Color(0xFFFFFFFF)
                                      : Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.4),
                                ),
                              );
                            }).toList(),
                          ),
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
                    Future.delayed(Duration(seconds: 4))
                        .then((value) => seeMoreLoader = false);
                  });
                }
              }
              return false;
            },
            child: GridView.builder(
              physics: ScrollPhysics(),
              padding: EdgeInsets.fromLTRB(5, 0, 5, 4),
              itemCount: Data.subPrismWalls.length == 0
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
                                  .returnTheme() ==
                              ThemeType.Dark
                          ? Colors.white10
                          : Colors.black.withOpacity(.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      onPressed: () {
                        if (!seeMoreLoader) {
                          Data.seeMorePrism();
                          setState(() {
                            seeMoreLoader = true;
                            Future.delayed(Duration(seconds: 4))
                                .then((value) => seeMoreLoader = false);
                          });
                        }
                      },
                      child: !seeMoreLoader ? Text("See more") : Loader());
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
                                  decoration: Data.subPrismWalls.length == 0
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
                                                  Provider.of<ThumbModel>(
                                                                  context,
                                                                  listen: false)
                                                              .thumbType ==
                                                          ThumbType.High
                                                      ? Data.subPrismWalls[
                                                              index]
                                                          ["wallpaper_url"]
                                                      : Data.subPrismWalls[
                                                              index]
                                                          ["wallpaper_thumb"]),
                                              fit: BoxFit.cover)),
                                )),
                            onTap: () {
                              if (Data.subPrismWalls == []) {
                              } else {
                                Navigator.pushNamed(context, WallpaperRoute,
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
                                    Data.subPrismWalls[index]["id"],
                                    widget.provider,
                                    Data.subPrismWalls[index]["wallpaper_url"],
                                    Data.subPrismWalls[index]
                                        ["wallpaper_thumb"]);
                              }
                            },
                          );
                        }));
              },
            ),
          ),
        ));
  }
}
