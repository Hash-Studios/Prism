import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/router.dart';
import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:Prism/ui/widgets/categoriesBar.dart';
import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

class CuratedScreen extends StatelessWidget {
  CuratedScreen({
    Key key,
  }) : super(key: key);

  Future<bool> onWillPop() async {
    String route = currentRoute;
    currentRoute = previousRoute;
    previousRoute = route;
    print(currentRoute);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: PreferredSize(
            child: CategoriesBar(
              current: "Curated",
            ),
            preferredSize: Size(double.infinity, 55),
          ),
          body: BottomBar(
            child: GridLoader(
              future: Provider.of<PexelsProvider>(context, listen: false)
                  .getDataP(),
              provider: "Pexels",
            ),
          )),
    );
  }
}
