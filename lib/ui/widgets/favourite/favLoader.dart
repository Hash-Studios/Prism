// import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/favourite/favGrid.dart';
import 'package:Prism/ui/widgets/home/gridLoader.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class FavLoader extends StatefulWidget {
  final Future<List> future;
  FavLoader({this.future});
  @override
  _FavLoaderState createState() => _FavLoaderState();
}

class _FavLoaderState extends State<FavLoader>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;
  Future<List> _future;
  @override
  void initState() {
    super.initState();
    // _future =
    //     Provider.of<FavouriteProvider>(context, listen: false).getDataBase();
    _future = widget.future;
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
        // if (snapshot.hasData) {
        //   print("has data");
        //   return FavouriteGrid();
        // } else {
        //   print("snapshot waiting");
        //   return CircularProgressIndicator();
        // }
        if (snapshot == null) {
          print("snapshot null");
          // return CircularProgressIndicator();
          return LoadingCards(controller: controller, animation: animation);
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          print("snapshot none, waiting");
          //   return CircularProgressIndicator();
          return LoadingCards(controller: controller, animation: animation);
        } else {
          return FavouriteGrid();
        }
      },
    );
  }
}
