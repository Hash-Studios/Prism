import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ColorGrid extends StatefulWidget {
  final String provider;
  const ColorGrid({required this.provider});
  @override
  _ColorGridState createState() => _ColorGridState();
}

class _ColorGridState extends State<ColorGrid> with TickerProviderStateMixin {
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

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    PData.wallsC = [];
    PData.getWallsPbyColor(widget.provider.substring(9));
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
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshHomeKey,
      onRefresh: refreshList,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            if (!seeMoreLoader) {
              PData.getWallsPbyColorPage(widget.provider.substring(9));
              setState(() {
                seeMoreLoader = true;
                Future.delayed(const Duration(seconds: 2))
                    .then((value) => seeMoreLoader = false);
              });
            }
          }
        } as bool Function(ScrollNotification)?,
        child: GridView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          itemCount: PData.wallsC.isEmpty ? 24 : PData.wallsC.length,
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
            if (index == PData.wallsC.length - 1) {
              return FlatButton(
                  color: Provider.of<ThemeModeExtended>(context)
                              .getCurrentModeStyle(
                                  MediaQuery.of(context).platformBrightness) ==
                          "Dark"
                      ? Colors.white10
                      : Colors.black.withOpacity(.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  onPressed: () {
                    if (!seeMoreLoader) {
                      PData.getWallsPbyColorPage(widget.provider.substring(9));
                      setState(() {
                        seeMoreLoader = true;
                        Future.delayed(const Duration(seconds: 2))
                            .then((value) => seeMoreLoader = false);
                      });
                    }
                  },
                  child: !seeMoreLoader ? const Text("See more") : Loader());
            }

            return FocusedMenuHolder(
                provider: widget.provider,
                index: index,
                child: AnimatedBuilder(
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
                              decoration: PData.wallsC.isEmpty
                                  ? BoxDecoration(
                                      color: animation.value,
                                      borderRadius: BorderRadius.circular(20),
                                    )
                                  : BoxDecoration(
                                      color: animation.value,
                                      borderRadius: BorderRadius.circular(20),
                                      image: DecorationImage(
                                          image: CachedNetworkImageProvider(
                                              PData.wallsC[index].src!["medium"]
                                                  .toString()),
                                          fit: BoxFit.cover)),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  splashColor: Theme.of(context)
                                      .accentColor
                                      .withOpacity(0.3),
                                  highlightColor: Theme.of(context)
                                      .accentColor
                                      .withOpacity(0.1),
                                  onTap: () {
                                    if (PData.wallsC == []) {
                                    } else {
                                      Navigator.pushNamed(
                                          context, wallpaperRoute, arguments: [
                                        widget.provider,
                                        index,
                                        PData.wallsC[index].src!["small"]
                                      ]);
                                    }
                                  },
                                  onLongPress: () {
                                    setState(() {
                                      longTapIndex = index;
                                    });
                                    shakeController.forward(from: 0.0);
                                    if (PData.wallsC == []) {
                                    } else {
                                      HapticFeedback.vibrate();
                                      createDynamicLink(
                                          PData.wallsC[index].id!,
                                          "Pexels",
                                          PData.wallsC[index].src!["original"]
                                              .toString(),
                                          PData.wallsC[index].src!["medium"]
                                              .toString());
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }));
          },
        ),
      ),
    );
  }
}
