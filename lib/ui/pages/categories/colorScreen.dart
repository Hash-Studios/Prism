import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/colorLoader.dart';
import 'package:Prism/ui/widgets/home/headingChipBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ColorScreen extends StatelessWidget {
  final List arguments;
  ColorScreen({
    Key key,
    @required this.arguments,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        int count = 0;
        while (navStack.last == "Color") {
          navStack.removeLast();
          count++;
        }
        print(navStack);
        print(count);
        for (int i = 0; i < count; i++) {
          Navigator.pop(context);
        }
        return false;
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: PreferredSize(
            child: HeadingChipBar(
              current: "Colors",
            ),
            preferredSize: Size(double.infinity, 55),
          ),
          body: BottomBar(
            child: ColorLoader(
              future: PData.getWallsPbyColor("color: ${arguments[0]}"),
              provider: "Colors - color: ${arguments[0]}",
            ),
          )),
    );
  }
}
