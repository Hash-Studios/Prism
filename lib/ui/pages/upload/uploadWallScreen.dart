import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';

class UploadWallScreen extends StatefulWidget {
  final List arguments;
  UploadWallScreen({this.arguments});
  @override
  _UploadWallScreenState createState() => _UploadWallScreenState();
}

class _UploadWallScreenState extends State<UploadWallScreen> {
  Future<bool> onWillPop() async {
    navStack.removeLast();
    print(navStack);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Upload",
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ),
        body: Container(),
      ),
    );
  }
}
