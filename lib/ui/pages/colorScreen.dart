import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:Prism/ui/widgets/categoriesBar.dart';
import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:Prism/ui/widgets/homeGrid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

class ColorScreen extends StatelessWidget {
  final List arguements;
  ColorScreen({
    Key key,
    @required this.arguements,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: PreferredSize(
          child: CategoriesBar(
            current: "Colors",
          ),
          preferredSize: Size(double.infinity, 55),
        ),
        body: BottomBar(
          child: GridLoader(
            future: Provider.of<PexelsProvider>(context, listen: false)
                .getWallsPbyColor("color: ${arguements[0]}"),
            provider: "Colors - color: ${arguements[0]}",
          ),
        ));
  }
}
