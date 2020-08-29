import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/collectionsViewGrid.dart';
import 'package:Prism/ui/widgets/home/headingChipBar.dart';
import 'package:flutter/material.dart';

class CollectionViewScreen extends StatelessWidget {
  final List arguments;
  CollectionViewScreen({
    Key key,
    @required this.arguments,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    print(arguments[1]);
    return WillPopScope(
      onWillPop: () async {
        if (navStack.length > 1) navStack.removeLast();
        print(navStack);
        return true;
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: PreferredSize(
            child: HeadingChipBar(
              current: arguments[0],
            ),
            preferredSize: Size(double.infinity, 55),
          ),
          body: BottomBar(
            child: CollectionViewGrid(arguments: arguments[1]),
          )),
    );
  }
}
