import 'package:auto_route/auto_route.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CollectionViewGrid extends StatefulWidget {
  const CollectionViewGrid();
  @override
  _CollectionViewGridState createState() => _CollectionViewGridState();
}

class _CollectionViewGridState extends State<CollectionViewGrid> with TickerProviderStateMixin {
  AnimationController? _controller;
  late AnimationController shakeController;
  late Animation<Color?> animation;
  int? longTapIndex;
  GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();

  bool seeMoreLoader = false;

  Future<void> _loadMore() async {
    if (seeMoreLoader || !collectionHasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
    });
    try {
      await seeMoreCollectionWithName();
    } finally {
      if (mounted) {
        setState(() {
          seeMoreLoader = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    animation =
        context.prismModeStyleForWindow(listen: false) == "Dark"
              ? TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: Colors.white10, end: const Color(0x22FFFFFF)),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: const Color(0x22FFFFFF), end: Colors.white10),
                  ),
                ]).animate(_controller!)
              : TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .1),
                      end: Colors.black.withValues(alpha: .14),
                    ),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .14),
                      end: Colors.black.withValues(alpha: .1),
                    ),
                  ),
                ]).animate(_controller!)
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
    final Animation<double> offsetAnimation =
        Tween(begin: 0.0, end: 8.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    final ScrollController? controller = InheritedDataProvider.of(context)!.scrollController;
    final List<Map<String, dynamic>> walls = anyCollectionWalls ?? <Map<String, dynamic>>[];
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
      itemCount: walls.length,
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
        childAspectRatio: 0.6625,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        if (index == walls.length - 1 && collectionHasMore && walls.length >= 24) {
          return SeeMoreButton(
            seeMoreLoader: seeMoreLoader,
            func: () {
              _loadMore();
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
                  ? EdgeInsets.symmetric(vertical: offsetAnimation.value / 2, horizontal: offsetAnimation.value)
                  : EdgeInsets.zero,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: animation.value,
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(walls[index]["wallpaper_thumb"].toString()),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                        highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                        onTap: () {
                          context.router.push(
                            ShareWallpaperViewRoute(
                              arguments: [
                                walls[index]["id"],
                                walls[index]["wallpaper_provider"],
                                walls[index]["wallpaper_url"],
                                walls[index]["wallpaper_thumb"],
                              ],
                            ),
                          );
                        },
                        onLongPress: () {
                          setState(() {
                            longTapIndex = index;
                          });
                          shakeController.forward(from: 0.0);
                          HapticFeedback.vibrate();
                          createDynamicLink(
                            walls[index]["id"].toString(),
                            walls[index]["wallpaper_provider"].toString(),
                            walls[index]["wallpaper_url"].toString(),
                            walls[index]["wallpaper_thumb"].toString(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
