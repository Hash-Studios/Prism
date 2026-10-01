import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/features/category_feed/views/widgets/color_grid.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ColorScreen extends StatelessWidget {
  const ColorScreen({super.key, required this.hexColor, required this.name});

  final String hexColor;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: "Colors"),
      ),
      body: ColorGrid(hexColor: hexColor, name: name),
    );
  }
}
