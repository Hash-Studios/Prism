import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/wallpapers/colorLoader.dart';
import 'package:Prism/ui/widgets/home/core/headingChipBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ColorScreen extends StatelessWidget {
  final List arguments;
  const ColorScreen({
    Key key,
    @required this.arguments,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        int count = 0;
        while (navStack.last == "Color") {
          navStack.removeLast();
          count++;
        }
        debugPrint(navStack.toString());
        debugPrint(count.toString());
        for (int i = 0; i < count; i++) {
          Navigator.pop(context);
        }
        if ((navStack.last == "Wallpaper") ||
            (navStack.last == "Search Wallpaper") ||
            (navStack.last == "SharedWallpaper") ||
            (navStack.last == "SetupView") ||
            (navStack.last == "User ProfileWallpaper")) {}
        return false;
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: const PreferredSize(
            preferredSize: Size(double.infinity, 55),
            child: HeadingChipBar(
              current: "Colors",
            ),
          ),
          body: BottomBar(
            child: ColorLoader(
              future: pdata.getWallsPbyColor("color: ${arguments[0]}"),
              provider: "Colors - color: ${arguments[0]}",
            ),
          )),
    );
  }
}
