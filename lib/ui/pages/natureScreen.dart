import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/router.dart';
import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NatureScreen extends StatefulWidget {
  NatureScreen({
    Key key,
  }) : super(key: key);

  @override
  _NatureScreenState createState() => _NatureScreenState();
}

class _NatureScreenState extends State<NatureScreen> {
  Future<bool> onWillPop() async {
    String route = currentRoute;
    currentRoute = previousRoute;
    previousRoute = route;
    print(currentRoute);
    return true;
  }

  @override
  void initState() {
    Provider.of<CategoryProvider>(context, listen: false)
        .updateSelectedCategory("Nature");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: GridLoader(
        future: Provider.of<PexelsProvider>(context, listen: false)
            .getNatureWalls(),
        provider: "Pexels",
      ),
    );
  }
}
