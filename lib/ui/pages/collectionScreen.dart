import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';

class CollectionScreen extends StatelessWidget {
  CollectionScreen({
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
      child: Container(),
    );
  }
}
