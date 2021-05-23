import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/collections/collectionsGrid.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/home/wallpapers/carouselDots.dart';
import 'package:Prism/ui/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/ui/widgets/home/wallpapers/wallpaperTile.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/global/globals.dart' as globals;
import 'package:url_launcher/url_launcher.dart';

class WallpaperGrid extends StatefulWidget {
  final String? provider;
  const WallpaperGrid({required this.provider});
  @override
  _WallpaperGridState createState() => _WallpaperGridState();
}

class _WallpaperGridState extends State<WallpaperGrid> {
  GlobalKey<RefreshIndicatorState> refreshHomeKey =
      GlobalKey<RefreshIndicatorState>();
  int _current = 0;
  bool seeMoreLoader = false;
  @override
  void initState() {
    super.initState();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    Data.prismWalls = [];
    Data.subPrismWalls = [];
    Data.getPrismWalls();
  }

  void showGooglePopUp(BuildContext context, Function func) {
    debugPrint(globals.prismUser.loggedIn.toString());
    if (globals.prismUser.loggedIn == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller =
        InheritedDataProvider.of(context)!.scrollController;
    final CarouselController carouselController = CarouselController();
    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: NestedScrollView(
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
                    itemBuilder: (BuildContext context, int i, int rI) => i == 4
                        ? Container(
                            width: MediaQuery.of(context).size.width,
                            margin: const EdgeInsets.fromLTRB(3, 1, 3, 6),
                            child: GestureDetector(
                              onTap: () {
                                launch(globals.bannerURL);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Provider.of<ThemeModeExtended>(
                                                    context)
                                                .getCurrentModeStyle(
                                                    MediaQuery.of(context)
                                                        .platformBrightness) ==
                                            "Dark"
                                        ? Colors.white10
                                        : Colors.black.withOpacity(.1),
                                    borderRadius: BorderRadius.circular(20),
                                    image: DecorationImage(
                                        image: CachedNetworkImageProvider(
                                            globals.topImageLink),
                                        fit: BoxFit.cover)),
                                child: Center(
                                  child: Container(
                                    width: MediaQuery.of(context).size.width,
                                    color: globals.bannerTextOn == "true"
                                        ? Colors.black.withOpacity(0.4)
                                        : Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        globals.bannerTextOn == "true"
                                            ? globals.bannerText.toUpperCase()
                                            : "",
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline2!
                                            .copyWith(
                                                fontSize: 20,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
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
                                  globals.isPremiumWall(
                                                  globals.premiumCollections,
                                                  Data.subPrismWalls![i]
                                                              ["collections"]
                                                          as List? ??
                                                      []) ==
                                              true &&
                                          globals.prismUser.premium != true
                                      ? showGooglePopUp(context, () {
                                          Navigator.pushNamed(
                                            context,
                                            premiumRoute,
                                          );
                                        })
                                      : Navigator.pushNamed(
                                          context, wallpaperRoute,
                                          arguments: [
                                              widget.provider,
                                              i,
                                              Data.subPrismWalls![i]
                                                  ["wallpaper_thumb"],
                                            ]);
                                }
                              },
                              child: Data.subPrismWalls!.isEmpty
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: Provider.of<ThemeModeExtended>(
                                                        context)
                                                    .getCurrentModeStyle(
                                                        MediaQuery.of(context)
                                                            .platformBrightness) ==
                                                "Dark"
                                            ? Colors.white10
                                            : Colors.black.withOpacity(.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    )
                                  : PremiumBannerWallsCarousel(
                                      comparator: !globals.isPremiumWall(
                                          globals.premiumCollections,
                                          Data.subPrismWalls![i]["collections"]
                                                  as List? ??
                                              []),
                                      child: Container(
                                        decoration: BoxDecoration(
                                            color: Provider.of<ThemeModeExtended>(
                                                            context)
                                                        .getCurrentModeStyle(
                                                            MediaQuery.of(context)
                                                                .platformBrightness) ==
                                                    "Dark"
                                                ? Colors.white10
                                                : Colors.black.withOpacity(.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            image: DecorationImage(
                                                image: CachedNetworkImageProvider(
                                                    Data.subPrismWalls![i]
                                                            ["wallpaper_thumb"]
                                                        .toString()),
                                                fit: BoxFit.cover)),
                                        child: Center(
                                          child: Container(
                                            width: MediaQuery.of(context)
                                                .size
                                                .width,
                                            color: Colors.transparent,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Text(
                                                "",
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headline2!
                                                    .copyWith(
                                                        color: Colors.white,
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                  ),
                  CarouselDots(current: _current),
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
                  setState(() {
                    seeMoreLoader = true;
                  });
                  Data.seeMorePrism();
                  setState(() {
                    Future.delayed(const Duration(seconds: 1))
                        .then((value) => seeMoreLoader = false);
                  });
                }
              }
              return false;
            },
            child: GridView.builder(
              physics: const ScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
              itemCount: Data.subPrismWalls!.isEmpty
                  ? 20
                  : Data.subPrismWalls!.length - 4,
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
                if (index == Data.subPrismWalls!.length - 1) {
                  return SeeMoreButton(
                    seeMoreLoader: seeMoreLoader,
                    func: () {
                      if (!seeMoreLoader) {
                        setState(() {
                          seeMoreLoader = true;
                        });
                        Data.seeMorePrism();
                        setState(() {
                          Future.delayed(const Duration(seconds: 1))
                              .then((value) => seeMoreLoader = false);
                        });
                      }
                    },
                  );
                }
                return globals.prismUser.premium == true
                    ? FocusedMenuHolder(
                        provider: widget.provider,
                        index: index,
                        child: WallpaperTile(widget: widget, index: index),
                      )
                    : PremiumBannerWalls(
                        comparator: !globals.isPremiumWall(
                            globals.premiumCollections,
                            Data.subPrismWalls![index]["collections"]
                                    as List? ??
                                []),
                        defaultChild: FocusedMenuHolder(
                          provider: widget.provider,
                          index: index,
                        
                          child: WallpaperTile(widget: widget, index: index),
                        ),
                        trueChild: WallpaperTile(widget: widget, index: index),
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}
