import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/focusedMenu.dart';
import 'package:Prism/ui/widgets/inheritedScrollControllerProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeGrid extends StatefulWidget {
  final String provider;
  HomeGrid({@required this.provider});
  @override
  _HomeGridState createState() => _HomeGridState();
}

class _HomeGridState extends State<HomeGrid>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;

  bool seeMoreLoader = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = ThemeModel().returnTheme() == ThemeType.Dark
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
  dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return GridView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
      itemCount: widget.provider == "WallHaven"
          ? Provider.of<WallHavenProvider>(context).walls.length == 0
              ? 24
              : Provider.of<WallHavenProvider>(context).walls.length
          : widget.provider == "Pexels"
              ? Provider.of<PexelsProvider>(context).wallsP.length == 0
                  ? 24
                  : Provider.of<PexelsProvider>(context).wallsP.length
              : widget.provider.length > 6 &&
                      widget.provider.substring(0, 6) == "Colors"
                  ? Provider.of<PexelsProvider>(context).wallsC.length == 0
                      ? 24
                      : Provider.of<PexelsProvider>(context).wallsC.length
                  : Provider.of<WallHavenProvider>(context).wallsS.length == 0
                      ? 24
                      : Provider.of<WallHavenProvider>(context).wallsS.length,
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent:
              MediaQuery.of(context).orientation == Orientation.portrait
                  ? 300
                  : 250,
          childAspectRatio: 0.830,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8),
      itemBuilder: (context, index) {
        if (widget.provider == "WallHaven") {
          if (index ==
              Provider.of<WallHavenProvider>(context).walls.length - 1) {
            return FlatButton(
                color: ThemeModel().returnTheme() == ThemeType.Dark
                    ? Colors.white10
                    : Colors.black.withOpacity(.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  if (!seeMoreLoader) {
                    Provider.of<WallHavenProvider>(context, listen: false)
                        .getData();
                    setState(() {
                      seeMoreLoader = true;
                      Future.delayed(Duration(seconds: 3))
                          .then((value) => seeMoreLoader = false);
                    });
                  }
                },
                child: !seeMoreLoader
                    ? Text("See more")
                    : CircularProgressIndicator());
          }
        } else if (widget.provider == "Pexels") {
          if (index == Provider.of<PexelsProvider>(context).wallsP.length - 1) {
            return FlatButton(
                color: ThemeModel().returnTheme() == ThemeType.Dark
                    ? Colors.white10
                    : Colors.black.withOpacity(.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  if (!seeMoreLoader) {
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getDataP();
                    setState(() {
                      seeMoreLoader = true;
                      Future.delayed(Duration(seconds: 3))
                          .then((value) => seeMoreLoader = false);
                    });
                  }
                },
                child: !seeMoreLoader
                    ? Text("See more")
                    : CircularProgressIndicator());
          }
        } else if (widget.provider.length > 6 &&
            widget.provider.substring(0, 6) == "Colors") {
          if (index == Provider.of<PexelsProvider>(context).wallsC.length - 1) {
            return FlatButton(
                color: ThemeModel().returnTheme() == ThemeType.Dark
                    ? Colors.white10
                    : Colors.black.withOpacity(.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  if (!seeMoreLoader) {
                    Provider.of<PexelsProvider>(context, listen: false)
                        .getWallsPbyColorPage(widget.provider.substring(9));
                    setState(() {
                      seeMoreLoader = true;
                      Future.delayed(Duration(seconds: 3))
                          .then((value) => seeMoreLoader = false);
                    });
                  }
                },
                child: !seeMoreLoader
                    ? Text("See more")
                    : CircularProgressIndicator());
          }
        } else {
          if (index ==
              Provider.of<WallHavenProvider>(context).wallsS.length - 1) {
            return FlatButton(
                color: ThemeModel().returnTheme() == ThemeType.Dark
                    ? Colors.white10
                    : Colors.black.withOpacity(.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  if (!seeMoreLoader) {
                    Provider.of<WallHavenProvider>(context, listen: false)
                        .getWallsbyQueryPage(widget.provider);
                    setState(() {
                      seeMoreLoader = true;
                      Future.delayed(Duration(seconds: 3))
                          .then((value) => seeMoreLoader = false);
                    });
                  }
                },
                child: !seeMoreLoader
                    ? Text("See more")
                    : CircularProgressIndicator());
          }
        }
        return FocusedMenuHolder(
          provider: widget.provider,
          index: index,
          child: GestureDetector(
            child: Container(
              decoration: widget.provider == "WallHaven"
                  ? Provider.of<WallHavenProvider>(context).walls.length == 0
                      ? BoxDecoration(
                          color: animation.value,
                          borderRadius: BorderRadius.circular(20),
                        )
                      : BoxDecoration(
                          color: animation.value,
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(
                              image: NetworkImage(Provider.of<WallHavenProvider>(context)
                                  .walls[index]
                                  .thumbs["original"]),
                              fit: BoxFit.cover))
                  : widget.provider == "Pexels"
                      ? Provider.of<PexelsProvider>(context).wallsP.length == 0
                          ? BoxDecoration(
                              color: animation.value,
                              borderRadius: BorderRadius.circular(20),
                            )
                          : BoxDecoration(
                              color: animation.value,
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                  image: NetworkImage(
                                      Provider.of<PexelsProvider>(context)
                                          .wallsP[index]
                                          .src["medium"]),
                                  fit: BoxFit.cover))
                      : widget.provider.length > 6 &&
                              widget.provider.substring(0, 6) == "Colors"
                          ? Provider.of<PexelsProvider>(context).wallsC.length ==
                                  0
                              ? BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                      image: NetworkImage(
                                          Provider.of<PexelsProvider>(context)
                                              .wallsC[index]
                                              .src["medium"]),
                                      fit: BoxFit.cover))
                          : Provider.of<WallHavenProvider>(context).wallsS.length == 0
                              ? BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : BoxDecoration(color: animation.value, borderRadius: BorderRadius.circular(20), image: DecorationImage(image: NetworkImage(Provider.of<WallHavenProvider>(context).wallsS[index].thumbs["original"]), fit: BoxFit.cover)),
            ),
            onTap: () {
              if (widget.provider == "WallHaven") {
                if (Provider.of<WallHavenProvider>(context, listen: false)
                        .walls ==
                    []) {
                } else {
                  Navigator.pushNamed(context, WallpaperRoute, arguments: [
                    widget.provider,
                    index,
                    Provider.of<WallHavenProvider>(context, listen: false)
                        .walls[index]
                        .thumbs["small"],
                  ]);
                }
              } else if (widget.provider == "Pexels") {
                if (Provider.of<PexelsProvider>(context, listen: false)
                        .wallsP ==
                    []) {
                } else {
                  Navigator.pushNamed(context, WallpaperRoute, arguments: [
                    widget.provider,
                    index,
                    Provider.of<PexelsProvider>(context, listen: false)
                        .wallsP[index]
                        .src["small"]
                  ]);
                }
              } else if (widget.provider.length > 6 &&
                  widget.provider.substring(0, 6) == "Colors") {
                if (Provider.of<PexelsProvider>(context, listen: false)
                        .wallsC ==
                    []) {
                } else {
                  Navigator.pushNamed(context, WallpaperRoute, arguments: [
                    widget.provider,
                    index,
                    Provider.of<PexelsProvider>(context, listen: false)
                        .wallsC[index]
                        .src["small"]
                  ]);
                }
              } else {
                if (Provider.of<WallHavenProvider>(context, listen: false)
                        .wallsS ==
                    []) {
                } else {
                  Navigator.pushNamed(context, WallpaperRoute, arguments: [
                    widget.provider,
                    index,
                    Provider.of<WallHavenProvider>(context, listen: false)
                        .wallsS[index]
                        .thumbs["small"],
                  ]);
                }
              }
            },
          ),
        );
      },
    );
  }
}
