import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/theme/thumbModel.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  var refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
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
                    ? 20000
                    : 20000,
            childAspectRatio: 1 / 0.6625,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
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
                            Provider.of<ThumbModel>(context, listen: false).thumbType ==
                                    ThumbType.High
                                ? CData.collections[CData.collectionNames.toList()[index]]
                                        [CData.collections[CData.collectionNames.toList()[index]].length - 1]
                                    ["wallpaper_url"]
                                : CData.collections[
                                    CData.collectionNames.toList()[index]][CData
                                        .collections[CData.collectionNames.toList()[index]]
                                        .length -
                                    1]["wallpaper_thumb"],
                          ),
                          fit: BoxFit.cover)),
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  color: Colors.black.withOpacity(0.4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      CData.collectionNames
                          .toList()[index]
                          .toString()
                          .toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.headline2.copyWith(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            onTap: () {
              if (CData.collections == {}) {
              } else {
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
              }
            },
          );
        },
      ),
    );
  }
}
