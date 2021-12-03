import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:prism/router/app_router.dart';
import 'package:prism/services/locator.dart';
import 'package:prism/services/logger.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  String shortcut = "No Action Set";
  @override
  void initState() {
    //TODO: Call important init functions here
    FlutterDisplayMode.setHighRefreshRate()
        .then(
          (value) => FlutterDisplayMode.active.then(
            (mode) => logger.d(
              "Refresh rate set to - ${mode.width}x${mode.height} @ ${mode.refreshRate}",
            ),
          ),
        )
        .then((value) => locator<AppRouter>().replaceAll([const HomeRoute()]));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
