import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/collections/collectionsViewGrid.dart';
import 'package:Prism/ui/widgets/home/core/headingChipBar.dart';
import 'package:flutter/material.dart';

class CollectionViewScreen extends StatelessWidget {
  final List arguments;
  const CollectionViewScreen({
    Key key,
    @required this.arguments,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    debugPrint(arguments[1].toString());
    return WillPopScope(
      onWillPop: () async {
        if (navStack.length > 1) navStack.removeLast();
        debugPrint(navStack.toString());
        return true;
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: PreferredSize(
            preferredSize: const Size(double.infinity, 55),
            child: HeadingChipBar(
              current: arguments[0] as String,
            ),
          ),
          body: BottomBar(
            child: CollectionViewGrid(arguments: arguments[1] as List),
          )),
    );
  }
}
