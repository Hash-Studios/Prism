import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/theme/thumbModel.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CollectionViewGrid extends StatefulWidget {
  final List arguments;
  CollectionViewGrid({@required this.arguments});
  @override
  _CollectionViewGridState createState() => _CollectionViewGridState();
}

class _CollectionViewGridState extends State<CollectionViewGrid>
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
    return GridView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(5, 0, 5, 4),
      itemCount: widget.arguments.length,
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
        return AnimatedBuilder(
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
                    decoration: BoxDecoration(
                        color: animation.value,
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                            image: CachedNetworkImageProvider(
                                Provider.of<ThumbModel>(context, listen: false)
                                            .thumbType ==
                                        ThumbType.High
                                    ? widget.arguments[index]["wallpaper_url"]
                                    : widget.arguments[index]
                                        ["wallpaper_thumb"]),
                            fit: BoxFit.cover)),
                  ),
                ),
                onTap: () {
                  Navigator.pushNamed(context, ShareRoute, arguments: [
                    widget.arguments[index]["id"],
                    widget.arguments[index]["wallpaper_provider"],
                    widget.arguments[index]["wallpaper_url"],
                    widget.arguments[index]["wallpaper_thumb"]
                  ]);
                },
                onLongPress: () {
                  setState(() {
                    longTapIndex = index;
                  });
                  shakeController.forward(from: 0.0);
                  HapticFeedback.vibrate();
                  createDynamicLink(
                      widget.arguments[index]["id"],
                      widget.arguments[index]["wallpaper_provider"],
                      widget.arguments[index]["wallpaper_url"],
                      widget.arguments[index]["wallpaper_thumb"]);
                },
              );
            });
      },
    );
  }
}
