import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/homeGrid.dart';
import 'package:Prism/ui/widgets/inheritedScrollControllerProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GridLoader extends StatefulWidget {
  final Future future;
  final String provider;
  GridLoader({@required this.future, @required this.provider});
  @override
  _GridLoaderState createState() => _GridLoaderState();
}

class _GridLoaderState extends State<GridLoader>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;
  Future _future;

  @override
  void initState() {
    if (widget.provider == "WallHaven") {
      Provider.of<WallHavenProvider>(context, listen: false).walls = [];
    } else if (widget.provider == "Pexels") {
      Provider.of<PexelsProvider>(context, listen: false).wallsP = [];
      // Provider.of<PexelsProvider>(context, listen: false).pageGetDataP = 1;
    }
    _future = widget.future;
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
                  begin: Colors.black12.withOpacity(.1),
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
    return FutureBuilder(
      future: _future,
      builder: (ctx, snapshot) {
        if (snapshot == null) {
          print("snapshot null");
          return LoadingCards(controller: controller, animation: animation);
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          print("snapshot none, waiting");
          return LoadingCards(controller: controller, animation: animation);
        } else {
          // print("snapshot done");
          return HomeGrid(
            provider: widget.provider,
          );
        }
      },
    );
  }
}

class LoadingCards extends StatelessWidget {
  const LoadingCards({
    Key key,
    @required this.controller,
    @required this.animation,
  }) : super(key: key);

  final ScrollController controller;
  final Animation<Color> animation;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
      itemCount: 24,
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
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: animation.value,
          ),
        );
      },
    );
  }
}
