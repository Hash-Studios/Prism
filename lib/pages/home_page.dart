import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:prism/services/logger.dart';
import 'package:prism/widgets/navigation_bar.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    logger.d('App init done.');
  }

  void _incrementCounter() {
    // context.read<ThemeController>().setDarkIsTrueBlack(false);
    context.read<ThemeController>().setSchemeIndex(
          (context.read<ThemeController>().schemeIndex + 1) % 40,
        );
  }

  @override
  Widget build(BuildContext context) {
    final darkAppBarContents =
        Theme.of(context).scaffoldBackgroundColor.computeLuminance() > 0.5;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        systemOverlayStyle: SystemUiOverlayStyle(
            statusBarIconBrightness:
                darkAppBarContents ? Brightness.dark : Brightness.light),
        title: Text(
          'Prism',
          style: TextStyle(
            color: darkAppBarContents
                ? Theme.of(context).bottomNavigationBarTheme.unselectedItemColor
                : Theme.of(context).appBarTheme.titleTextStyle?.color,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
            color: darkAppBarContents
                ? Theme.of(context).bottomNavigationBarTheme.unselectedItemColor
                : Theme.of(context).appBarTheme.titleTextStyle?.color,
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
            color: darkAppBarContents
                ? Theme.of(context).bottomNavigationBarTheme.unselectedItemColor
                : Theme.of(context).appBarTheme.titleTextStyle?.color,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor:
            Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.image),
            icon: Icon(Icons.image_outlined),
            label: 'Walls',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.imagesearch_roller),
            icon: Icon(Icons.imagesearch_roller_outlined),
            label: 'Setups',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.notifications),
            icon: Icon(Icons.notifications_outlined),
            label: 'Notifications',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person),
            icon: Icon(Icons.person_outlined),
            label: 'Profile',
          ),
        ],
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Current theme index:',
                ),
                Text(
                  '${context.read<ThemeController>().schemeIndex}',
                  style: Theme.of(context).textTheme.headline4,
                ),
                SwitchListTile(
                  title: const Text('True Black'),
                  value: context.read<ThemeController>().darkIsTrueBlack,
                  onChanged: (value) {
                    context.read<ThemeController>().setDarkIsTrueBlack(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('True White'),
                  value: context.read<ThemeController>().lightIsWhite,
                  onChanged: (value) {
                    context.read<ThemeController>().setLightIsWhite(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Level Surfaces'),
                  value: context.read<ThemeController>().surfaceMode ==
                      FlexSurfaceMode.levelSurfacesLowScaffold,
                  onChanged: (value) {
                    context.read<ThemeController>().setSurfaceMode(value
                        ? FlexSurfaceMode.levelSurfacesLowScaffold
                        : FlexSurfaceMode.highScaffoldLowSurface);
                    value
                        ? context.read<ThemeController>().setBlendLevel(30)
                        : context.read<ThemeController>().setBlendLevel(18);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 10,
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
