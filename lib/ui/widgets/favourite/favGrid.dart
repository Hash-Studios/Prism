import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/gridLoader.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavouriteGrid extends StatefulWidget {
  const FavouriteGrid({
    Key key,
  }) : super(key: key);

  @override
  _FavouriteGridState createState() => _FavouriteGridState();
}

class _FavouriteGridState extends State<FavouriteGrid>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;
  // String userId = '';
  var refreshFavKey = GlobalKey<RefreshIndicatorState>();

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
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<Null> refreshList() async {
    refreshFavKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(milliseconds: 500));
    Provider.of<FavouriteProvider>(context, listen: false).getDataBase();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshFavKey,
        onRefresh: refreshList,
        child: Provider.of<FavouriteProvider>(context, listen: false).liked !=
                null
            ? GridView.builder(
                controller: controller,
                shrinkWrap: true,
                cacheExtent: 50000,
                padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                itemCount:
                    Provider.of<FavouriteProvider>(context, listen: false)
                                .liked
                                .length ==
                            0
                        ? 0
                        : Provider.of<FavouriteProvider>(context).liked.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: MediaQuery.of(context).orientation ==
                            Orientation.portrait
                        ? 300
                        : 250,
                    childAspectRatio: 0.830,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8),
                itemBuilder: (context, index) {
                  // print(Provider.of<FavouriteProvider>(context, listen: false)
                  //     .liked[index]);
                  // print(index);
                  return FocusedMenuHolder(
                    provider: "Liked",
                    index: index,
                    child: GestureDetector(
                      child: Container(
                        decoration: BoxDecoration(
                            color: animation.value,
                            borderRadius: BorderRadius.circular(20),
                            image: DecorationImage(
                                image: NetworkImage(
                                  Provider.of<FavouriteProvider>(context)
                                      .liked[index]["thumb"],
                                ),
                                fit: BoxFit.cover)),
                      ),
                      onTap: () {
                        if (Provider.of<FavouriteProvider>(context,
                                    listen: false)
                                .liked ==
                            []) {
                        } else {
                          Navigator.pushNamed(context, FavWallViewRoute,
                              arguments: [
                                index,
                                Provider.of<FavouriteProvider>(context,
                                        listen: false)
                                    .liked[index]["thumb"],
                              ]);
                        }
                      },
                    ),
                  );
                })
            : LoadingCards(controller: controller, animation: animation));
  }
}
