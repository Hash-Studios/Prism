import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/gridLoader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MarvelScreen extends StatelessWidget {
  MarvelScreen({
    Key key,
  }) : super(key: key);

  Future<bool> onWillPop() async {
    navStack.removeLast();
    print(navStack);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: GridLoader(
        future: Provider.of<WallHavenProvider>(context, listen: false)
            .getMarvelWalls(),
        provider: "WallHaven",
      ),
    );
  }
}
