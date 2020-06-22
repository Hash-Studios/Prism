import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/focusedMenu.dart';
import 'package:Prism/ui/widgets/inheritedScrollControllerProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeGrid extends StatefulWidget {
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
    // print("building home grid");
    return GridView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: Provider.of<WallHavenProvider>(context).walls.length == 0
          ? 24
          : Provider.of<WallHavenProvider>(context).walls.length,
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          childAspectRatio: 0.830,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8),
      itemBuilder: (context, index) {
        if (index == Provider.of<WallHavenProvider>(context).walls.length - 1) {
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
        return FocusedMenuHolder(
          index: index,
          child: Container(
            decoration:
                Provider.of<WallHavenProvider>(context).walls.length == 0
                    ? BoxDecoration(
                        color: animation.value,
                        borderRadius: BorderRadius.circular(20),
                      )
                    : BoxDecoration(
                        color: animation.value,
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                            image: NetworkImage(
                                Provider.of<WallHavenProvider>(context)
                                    .walls[index]
                                    .thumbs["small"]),
                            fit: BoxFit.cover)),
          ),
        );
      },
    );
  }
}
