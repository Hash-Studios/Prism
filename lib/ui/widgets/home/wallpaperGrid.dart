import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;

class WallpaperGrid extends StatefulWidget {
  final String provider;
  WallpaperGrid({@required this.provider});
  @override
  _WallpaperGridState createState() => _WallpaperGridState();
}

class _WallpaperGridState extends State<WallpaperGrid>
    with TickerProviderStateMixin {
  AnimationController _controller;
  AnimationController shakeController;
  Animation<Color> animation;
  int longTapIndex;
  var refreshHomeKey = GlobalKey<RefreshIndicatorState>();

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
    shakeController.dispose();
    super.dispose();
  }

  Future<Null> refreshList() async {
    refreshHomeKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(milliseconds: 500));
    Data.prismWalls = [];
    Data.subPrismWalls = [];
    Data.getPrismWalls();
    return null;
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
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshHomeKey,
      onRefresh: refreshList,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            if (!seeMoreLoader) {
              Data.seeMorePrism();
              setState(() {
                seeMoreLoader = true;
                Future.delayed(Duration(seconds: 4))
                    .then((value) => seeMoreLoader = false);
              });
            }
          }
        },
        child: GridView.builder(
          controller: controller,
          padding: EdgeInsets.fromLTRB(5, 0, 5, 4),
          itemCount:
              Data.subPrismWalls.length == 0 ? 24 : Data.subPrismWalls.length,
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
            if (index == Data.subPrismWalls.length - 1) {
              return FlatButton(
                  color: Provider.of<ThemeModel>(context, listen: false)
                              .returnTheme() ==
                          ThemeType.Dark
                      ? Colors.white10
                      : Colors.black.withOpacity(.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  onPressed: () {
                    if (!seeMoreLoader) {
                      Data.seeMorePrism();
                      setState(() {
                        seeMoreLoader = true;
                        Future.delayed(Duration(seconds: 4))
                            .then((value) => seeMoreLoader = false);
                      });
                    }
                  },
                  child: !seeMoreLoader ? Text("See more") : Loader());
            }
            return FocusedMenuHolder(
                provider: widget.provider,
                index: index,
                child: AnimatedBuilder(
                    animation: offsetAnimation,
                    builder: (buildContext, child) {
                      if (offsetAnimation.value < 0.0)
                        print('${offsetAnimation.value + 8.0}');
                      return GestureDetector(
                        child: Padding(
                          padding: index == longTapIndex
                              ? EdgeInsets.symmetric(
                                  vertical: offsetAnimation.value / 2,
                                  horizontal: offsetAnimation.value)
                              : EdgeInsets.all(0),
                          child: Container(
                            decoration: Data.subPrismWalls.length == 0
                                ? BoxDecoration(
                                    color: animation.value,
                                    borderRadius: BorderRadius.circular(20),
                                  )
                                : BoxDecoration(
                                    color: animation.value,
                                    borderRadius: BorderRadius.circular(20),
                                    image: DecorationImage(
                                        image: NetworkImage(
                                            Data.subPrismWalls[index]
                                                ["wallpaper_thumb"]),
                                        fit: BoxFit.cover)),
                          ),
                        ),
                        onTap: () {
                          if (Data.subPrismWalls == []) {
                          } else {
                            Navigator.pushNamed(context, WallpaperRoute,
                                arguments: [
                                  widget.provider,
                                  index,
                                  Data.subPrismWalls[index]["wallpaper_thumb"],
                                ]);
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            longTapIndex = index;
                          });
                          shakeController.forward(from: 0.0);
                          if (Data.subPrismWalls == []) {
                          } else {
                            HapticFeedback.vibrate();
                            createDynamicLink(
                                Data.subPrismWalls[index]["id"],
                                widget.provider,
                                Data.subPrismWalls[index]["wallpaper_url"],
                                Data.subPrismWalls[index]["wallpaper_thumb"]);
                          }
                        },
                      );
                    }));
          },
        ),
      ),
    );
  }
}
