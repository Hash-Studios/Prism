import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/router.dart';
import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:Prism/ui/widgets/categoriesBar.dart';
import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:Prism/ui/widgets/headingChipBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

class ColorScreen extends StatefulWidget {
  final List arguments;
  ColorScreen({
    Key key,
    @required this.arguments,
  }) : super(key: key);

  @override
  _ColorScreenState createState() => _ColorScreenState();
}

class _ColorScreenState extends State<ColorScreen> {
  Future<bool> onWillPop() async {
    String route = currentRoute;
    currentRoute = previousRoute;
    previousRoute = route;
    print(currentRoute);
    return true;
  }

  @override
  void initState() {
    // Provider.of<CategoryProvider>(context, listen: false)
    //     .updateCategories(["Colors"]);
    // Provider.of<CategoryProvider>(context, listen: false)
    //     .updateSelectedCategory("Colors");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: PreferredSize(
            child: HeadingChipBar(
              current: "Colors",
            ),
            preferredSize: Size(double.infinity, 55),
          ),
          body: BottomBar(
            child: GridLoader(
              future: Provider.of<PexelsProvider>(context, listen: false)
                  .getWallsPbyColor("color: ${widget.arguments[0]}"),
              provider: "Colors - color: ${widget.arguments[0]}",
            ),
          )),
    );
  }
}
