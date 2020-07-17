import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/gridLoader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SportsScreen extends StatelessWidget {
  SportsScreen({
    Key key,
  }) : super(key: key);

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: GridLoader(
        future: Provider.of<PexelsProvider>(context, listen: false)
            .getSportsWalls(),
        provider: "Pexels",
      ),
    );
  }
}
