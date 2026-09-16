import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/data/pexels/provider/pexels_without_provider.dart' as pexels_data;
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
      body: ColorLoader(
        future: pexels_data.getWallsPbyColor("color: $hexColor"),
        provider: "Colors - color: $hexColor",
      ),
    );
  }
}
