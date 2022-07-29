import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:prism/controllers/wallhaven_controller.dart';
import 'package:prism/model/wallhaven/wallhaven_categories.dart';
import 'package:prism/model/wallhaven/wallhaven_purity.dart';
import 'package:prism/model/wallhaven/wallhaven_sorting.dart';
import 'package:prism/router/app_router.dart';
import 'package:prism/services/locator.dart';
import 'package:prism/services/logger.dart';
import 'package:provider/provider.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  LoadingPageState createState() => LoadingPageState();
}

class LoadingPageState extends State<LoadingPage> {
  String shortcut = "No Action Set";
  @override
  void initState() {
    //TODO: Call important init functions here
    FlutterDisplayMode.setHighRefreshRate().then(
      (value) => FlutterDisplayMode.active.then(
        (mode) => logger.d(
          "Refresh rate set to - ${mode.width}x${mode.height} @ ${mode.refreshRate}",
        ),
      ),
    );
    Future.delayed(Duration.zero, () {
      context.read<WallHavenController>().purity = Purity.onlySfw;
      context.read<WallHavenController>().categories = Categories.onlyGeneral;
      context.read<WallHavenController>().sorting = Sorting.dateAdded;
      context.read<WallHavenController>().getSearchResults().then(
          (value) => locator<AppRouter>().replaceAll([const HomeRoute()]));
    });
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
