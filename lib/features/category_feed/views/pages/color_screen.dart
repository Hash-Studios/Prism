import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/features/category_feed/views/widgets/color_loader.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

class ColorScreen extends StatelessWidget {
  final List? arguments;
  const ColorScreen({
    super.key,
    required this.arguments,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        int count = 0;
        while (currentNavStackEntry == "Color") {
          popNavStack();
          count++;
        }
        logger.d(count.toString());
        for (int i = 0; i < count; i++) {
          Navigator.pop(context);
        }
        if ((currentNavStackEntry == "Wallpaper") ||
            (currentNavStackEntry == "Search Wallpaper") ||
            (currentNavStackEntry == "SharedWallpaper") ||
            (currentNavStackEntry == "SetupView") ||
            (currentNavStackEntry == "User ProfileWallpaper")) {}
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
              future: pdata.getWallsPbyColor("color: ${arguments![0]}"),
              provider: "Colors - color: ${arguments![0]}",
            ),
          )),
    );
  }
}
