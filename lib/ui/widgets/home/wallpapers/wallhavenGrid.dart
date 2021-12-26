import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as wData;
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/home/wallpapers/carouselDots.dart';
import 'package:Prism/ui/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/ui/widgets/home/wallpapers/wallhavenTile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class WallHavenGrid extends StatefulWidget {
  final String? provider;
  const WallHavenGrid({required this.provider});
  @override
  _WallHavenGridState createState() => _WallHavenGridState();
}

class _WallHavenGridState extends State<WallHavenGrid> {
  int _current = 0;
  GlobalKey<RefreshIndicatorState> refreshHomeKey =
      GlobalKey<RefreshIndicatorState>();

  bool seeMoreLoader = false;
  @override
  void initState() {
    super.initState();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    wData.walls = [];
    Provider.of<CategorySupplier>(context, listen: false).changeWallpaperFuture(
        Provider.of<CategorySupplier>(context, listen: false).selectedChoice,
        "r");
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
                            margin: const EdgeInsets.fromLTRB(5, 1, 5, 7),
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
                            margin: const EdgeInsets.fromLTRB(5, 1, 5, 7),
                            child: GestureDetector(
                              onTap: () {
                                if (wData.walls == []) {
                                } else {
                                  Navigator.pushNamed(context, wallpaperRoute,
                                      arguments: [
                                        widget.provider,
                                        i,
                                        wData.walls[i].thumbs!["small"],
                                      ]);
                                }
                              },
                              child: wData.walls.isEmpty
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
                                  : Container(
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
                                                  wData.walls[i]
                                                      .thumbs!["original"]
                                                      .toString()),
                                              fit: BoxFit.cover)),
                                      child: Center(
                                        child: Container(
                                          width:
                                              MediaQuery.of(context).size.width,
                                          color: Colors.transparent,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
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
                  Provider.of<CategorySupplier>(context, listen: false)
                      .changeWallpaperFuture(
                          Provider.of<CategorySupplier>(context, listen: false)
                              .selectedChoice,
                          "s");

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
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
              itemCount: wData.walls.isEmpty ? 20 : wData.walls.length - 4,
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
                if (index == wData.walls.length - 1) {
                  return SeeMoreButton(
                    seeMoreLoader: seeMoreLoader,
                    func: () {
                      if (!seeMoreLoader) {
                        Provider.of<CategorySupplier>(context, listen: false)
                            .changeWallpaperFuture(
                                Provider.of<CategorySupplier>(context,
                                        listen: false)
                                    .selectedChoice,
                                "s");

                        setState(
                          () {
                            seeMoreLoader = true;
                            Future.delayed(const Duration(seconds: 2))
                                .then((value) => seeMoreLoader = false);
                          },
                        );
                      }
                    },
                  );
                }
                return FocusedMenuHolder(
                  provider: widget.provider,
                  index: index,
                  child: WallhavenTile(widget: widget, index: index),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
