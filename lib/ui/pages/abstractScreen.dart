import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/router.dart';
import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:Prism/ui/widgets/categoriesBar.dart';
import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

class AbstractScreen extends StatefulWidget {
  AbstractScreen({
    Key key,
  }) : super(key: key);

  @override
  _AbstractScreenState createState() => _AbstractScreenState();
}

class _AbstractScreenState extends State<AbstractScreen> {
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
    //     .updateSelectedCategory("Abstract");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: GridLoader(
        future: Provider.of<PexelsProvider>(context, listen: false)
            .getAbstractWalls(),
        provider: "Pexels",
      ),
    );
  }
}
