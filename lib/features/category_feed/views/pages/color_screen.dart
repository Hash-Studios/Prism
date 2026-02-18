import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/features/category_feed/views/widgets/color_loader.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class ColorScreen extends StatelessWidget {
  final List? arguments;
  const ColorScreen({super.key, required this.arguments});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: "Colors"),
      ),
      body: BottomBar(
        child: ColorLoader(
          future: pdata.getWallsPbyColor("color: ${arguments![0]}"),
          provider: "Colors - color: ${arguments![0]}",
        ),
      ),
    );
  }
}
