import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/gridLoader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CodeScreen extends StatelessWidget {
  CodeScreen({
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
        future: Provider.of<WallHavenProvider>(context, listen: false)
            .getCodeWalls(),
        provider: "WallHaven",
      ),
    );
  }
}
