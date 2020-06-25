import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/ui/widgets/focusedMenu.dart';
import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavouriteGrid extends StatefulWidget {
  const FavouriteGrid({
    Key key,
    @required this.controller,
    @required this.animation,
  }) : super(key: key);

  final ScrollController controller;
  final Animation<Color> animation;
  @override
  _FavouriteGridState createState() => _FavouriteGridState();
}

class _FavouriteGridState extends State<FavouriteGrid> {
  String userId = '';
  var refreshFavKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
    return RefreshIndicator(
        key: refreshFavKey,
        onRefresh: refreshList,
        child: Provider.of<FavouriteProvider>(context).liked != null
            ? GridView.builder(
                controller: widget.controller,
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                itemCount:
                    Provider.of<FavouriteProvider>(context).liked.length == 0
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
                  return FocusedMenuHolder(
                    provider: "WallHaven",
                    index: index,
                    child: GestureDetector(
                      child: Container(
                        decoration: BoxDecoration(
                            color: widget.animation.value,
                            borderRadius: BorderRadius.circular(20),
                            image: DecorationImage(
                                image: NetworkImage(
                                  Provider.of<FavouriteProvider>(context)
                                      .liked[index]["thumb"],
                                ),
                                fit: BoxFit.cover)),
                      ),
                      onTap: () {},
                    ),
                  );
                })
            : LoadingCards(
                controller: widget.controller, animation: widget.animation));
  }
}
