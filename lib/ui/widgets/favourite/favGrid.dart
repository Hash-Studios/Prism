import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/favourite/favourite_walls_legacy_bridge.dart';
import 'package:Prism/ui/theme/theme_bloc_utils.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FavouriteGrid extends StatefulWidget {
  const FavouriteGrid({
    super.key,
  });

  @override
  _FavouriteGridState createState() => _FavouriteGridState();
}

class _FavouriteGridState extends State<FavouriteGrid> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<Color?> animation;
  GlobalKey<RefreshIndicatorState> refreshFavKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = context.prismModeStyleForWindow(listen: false) == "Dark"
        ? TweenSequence<Color?>(
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
          ).animate(_controller!)
        : TweenSequence<Color?>(
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
          ).animate(_controller!)
      ..addListener(() {
        setState(() {});
      });
    _controller!.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> refreshList() async {
    refreshFavKey.currentState?.show();
    context.favouriteWallsLegacyProvider(listen: false).getDataBase();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller = InheritedDataProvider.of(context)!.scrollController;
    return RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshFavKey,
        onRefresh: refreshList,
        child: context.favouriteWallsLegacyProvider(listen: false).liked != null
            ? context.favouriteWallsLegacyProvider(listen: false).liked!.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: context.prismModeStyleForContext() == "Dark"
                            ? SvgPicture.string(
                                favouritesDark
                                    .replaceAll(
                                        "181818", Theme.of(context).primaryColor.value.toRadixString(16).substring(2))
                                    .replaceAll(
                                        "E57697",
                                        Theme.of(context)
                                            .colorScheme
                                            .error
                                            .toString()
                                            .replaceAll("Color(0xff", "")
                                            .replaceAll(")", ""))
                                    .replaceAll("F0F0F0",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll("2F2E41",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll("3F3D56",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll(
                                        "2F2F2F", Theme.of(context).hintColor.value.toRadixString(16).substring(2)),
                              )
                            : SvgPicture.string(
                                favouritesLight
                                    .replaceAll(
                                        "181818", Theme.of(context).primaryColor.value.toRadixString(16).substring(2))
                                    .replaceAll(
                                        "E57697",
                                        Theme.of(context)
                                            .colorScheme
                                            .error
                                            .toString()
                                            .replaceAll("Color(0xff", "")
                                            .replaceAll(")", ""))
                                    .replaceAll("F0F0F0",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll("2F2E41",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll("3F3D56",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll(
                                        "2F2F2F", Theme.of(context).hintColor.value.toRadixString(16).substring(2)),
                              ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.1,
                      )
                    ],
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    cacheExtent: 50000,
                    padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                    controller: controller,
                    itemCount: context.favouriteWallsLegacyProvider().liked!.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                        childAspectRatio: 0.6625,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8),
                    itemBuilder: (context, index) {
                      return FocusedMenuHolder(
                        provider: "Liked",
                        index: index,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        context.favouriteWallsLegacyProvider().liked![index]["thumb"].toString(),
                                      ),
                                      fit: BoxFit.cover)),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  splashColor: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                                  highlightColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                  onTap: () {
                                    if (context.favouriteWallsLegacyProvider(listen: false).liked == []) {
                                    } else {
                                      Navigator.pushNamed(context, favWallViewRoute, arguments: [
                                        index,
                                        context.favouriteWallsLegacyProvider(listen: false).liked![index]["thumb"],
                                      ]);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    })
            : const LoadingCards());
  }
}
