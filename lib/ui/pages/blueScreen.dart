import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:Prism/ui/widgets/categoriesBar.dart';
import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:Prism/ui/widgets/homeGrid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

class BlueScreen extends StatelessWidget {
  BlueScreen({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: PreferredSize(
          child: CategoriesBar(
            current: "Blue",
          ),
          preferredSize: Size(double.infinity, 55),
        ),
        body: BottomBar(
          child: GridLoader(
            future: Provider.of<PexelsProvider>(context, listen: false)
                .getBlueWalls(),
            provider: "Pexels",
          ),
        ));
  }
}
