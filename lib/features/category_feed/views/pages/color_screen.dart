import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/features/category_feed/views/widgets/color_loader.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ColorScreen extends StatelessWidget {
  const ColorScreen({super.key, required this.hexColor});

  final String hexColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: "Colors"),
      ),
      body: ColorLoader(future: pdata.getWallsPbyColor("color: $hexColor"), provider: "Colors - color: $hexColor"),
    );
  }
}
