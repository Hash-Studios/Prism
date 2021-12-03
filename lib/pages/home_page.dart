import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:prism/router/app_router.dart';
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
    return AutoTabsRouter(
        routes: const [
          WallsRoute(),
          SetupsRoute(),
          NotificationsRoute(),
          ProfileRoute(),
        ],
        homeIndex: 0,
        builder: (context, child, animation) {
          final tabsRouter = AutoTabsRouter.of(context);
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
                      ? Theme.of(context)
                          .bottomNavigationBarTheme
                          .unselectedItemColor
                      : Theme.of(context).appBarTheme.titleTextStyle?.color,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                  color: darkAppBarContents
                      ? Theme.of(context)
                          .bottomNavigationBarTheme
                          .unselectedItemColor
                      : Theme.of(context).appBarTheme.titleTextStyle?.color,
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list),
                  color: darkAppBarContents
                      ? Theme.of(context)
                          .bottomNavigationBarTheme
                          .unselectedItemColor
                      : Theme.of(context).appBarTheme.titleTextStyle?.color,
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tabsRouter.activeIndex,
              onDestinationSelected: (value) {
                tabsRouter.setActiveIndex(value);
                setState(() {});
              },
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
            body: child,
            floatingActionButton: FloatingActionButton(
              elevation: 10,
              onPressed: _incrementCounter,
              tooltip: 'Increment',
              child: const Icon(Icons.add),
            ),
          );
        });
  }
}
