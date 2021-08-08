import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/ui/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/logger/logger.dart';

class CollectionViewGrid extends StatefulWidget {
  const CollectionViewGrid();
  @override
  _CollectionViewGridState createState() => _CollectionViewGridState();
}

class _CollectionViewGridState extends State<CollectionViewGrid>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  late AnimationController shakeController;
  late Animation<Color?> animation;
  int? longTapIndex;
  GlobalKey<RefreshIndicatorState> refreshHomeKey =
      GlobalKey<RefreshIndicatorState>();

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
    animation = Provider.of<ThemeModeExtended>(context, listen: false)
                .getCurrentModeStyle(
                    SchedulerBinding.instance!.window.platformBrightness) ==
            "Dark"
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
    shakeController.dispose();
    super.dispose();
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
    final ScrollController? controller =
        InheritedDataProvider.of(context)!.scrollController;
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
      itemCount: anyCollectionWalls!.length,
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
        if (index == anyCollectionWalls!.length - 1 &&
            !(anyCollectionWalls!.length < 24)) {
          return SeeMoreButton(
            seeMoreLoader: seeMoreLoader,
            func: () {
              if (!seeMoreLoader) {
                setState(() {
                  seeMoreLoader = true;
                });
                seeMoreCollectionWithName();
                setState(() {
                  Future.delayed(const Duration(seconds: 1))
                      .then((value) => seeMoreLoader = false);
                });
              }
            },
          );
        }
        return AnimatedBuilder(
            animation: offsetAnimation,
            builder: (buildContext, child) {
              if (offsetAnimation.value < 0.0) {
                logger.d('${offsetAnimation.value + 8.0}');
              }
              return Padding(
                padding: index == longTapIndex
                    ? EdgeInsets.symmetric(
                        vertical: offsetAnimation.value / 2,
                        horizontal: offsetAnimation.value)
                    : const EdgeInsets.all(0),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          color: animation.value,
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(
                              image: CachedNetworkImageProvider(
                                  anyCollectionWalls![index]["wallpaper_thumb"]
                                      .toString()),
                              fit: BoxFit.cover)),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor:
                              Theme.of(context).accentColor.withOpacity(0.3),
                          highlightColor:
                              Theme.of(context).accentColor.withOpacity(0.1),
                          onTap: () {
                            Navigator.pushNamed(context, shareRoute,
                                arguments: [
                                  anyCollectionWalls![index]["id"],
                                  anyCollectionWalls![index]
                                      ["wallpaper_provider"],
                                  anyCollectionWalls![index]["wallpaper_url"],
                                  anyCollectionWalls![index]["wallpaper_thumb"]
                                ]);
                          },
                          onLongPress: () {
                            setState(() {
                              longTapIndex = index;
                            });
                            shakeController.forward(from: 0.0);
                            HapticFeedback.vibrate();
                            createDynamicLink(
                                anyCollectionWalls![index]["id"].toString(),
                                anyCollectionWalls![index]["wallpaper_provider"]
                                    .toString(),
                                anyCollectionWalls![index]["wallpaper_url"]
                                    .toString(),
                                anyCollectionWalls![index]["wallpaper_thumb"]
                                    .toString());
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            });
      },
    );
  }
}
