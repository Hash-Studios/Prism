import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/collections/collectionsGrid.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/ui/widgets/home/wallpapers/trendingTile.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/main.dart' as main;

class TrendingGrid extends StatefulWidget {
  final String provider;
  const TrendingGrid({@required this.provider});
  @override
  _TrendingGridState createState() => _TrendingGridState();
}

class _TrendingGridState extends State<TrendingGrid> {
  GlobalKey<RefreshIndicatorState> refreshTrendingKey =
      GlobalKey<RefreshIndicatorState>();
  bool seeMoreLoader = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> refreshList() async {
    refreshTrendingKey.currentState?.show();
    await Future.delayed(const Duration(milliseconds: 500));
    Data.prismWalls = [];
    Data.subPrismWalls = [];
    Data.sortedData = [];
    Data.subSortedData = [];
    Data.getTrendingWalls();
  }

  void showGooglePopUp(BuildContext context, Function func) {
    debugPrint(main.prefs.get("isLoggedin").toString());
    if (main.prefs.get("isLoggedin") == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshTrendingKey,
        onRefresh: refreshList,
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels ==
                scrollInfo.metrics.maxScrollExtent) {
              if (!seeMoreLoader) {
                Data.seeMoreTrending();
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
            physics: const ScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
            itemCount:
                Data.subSortedData.isEmpty ? 24 : Data.subSortedData.length,
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
              if (index == Data.subSortedData.length - 1) {
                return SeeMoreButton(
                  seeMoreLoader: seeMoreLoader,
                  func: () {
                    if (!seeMoreLoader) {
                      Data.seeMorePrism();
                      setState(() {
                        seeMoreLoader = true;
                        Future.delayed(const Duration(seconds: 2))
                            .then((value) => seeMoreLoader = false);
                      });
                    }
                  },
                );
              }
              return main.prefs.get('premium') == true
                  ? FocusedMenuHolder(
                      provider: widget.provider,
                      index: index,
                      // child: AnimatedBuilder(
                      // builder: (buildContext, child) {
                      child: TrendingTile(widget: widget, index: index),
                      // },
                      // ),
                    )
                  : PremiumBannerWalls(
                      comparator: !globals.isPremiumWall(
                          globals.premiumCollections,
                          Data.subSortedData[index]["collections"] as List ??
                              []),
                      defaultChild: FocusedMenuHolder(
                        provider: widget.provider,
                        index: index,
                        // child: AnimatedBuilder(
                        // builder: (buildContext, child) {
                        child: TrendingTile(widget: widget, index: index),
                        // },
                        // ),
                      ),
                      trueChild: TrendingTile(widget: widget, index: index),
                    );
            },
          ),
        ),
      ),
    );
  }
}
