import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:prism/controllers/hide_controller.dart';
import 'package:prism/controllers/setup_controller.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:prism/controllers/toast_controller.dart';
import 'package:prism/controllers/wallhaven_controller.dart';
import 'package:prism/router/app_router.dart';
import 'package:prism/services/locator.dart';
import 'package:prism/services/logger.dart';
import 'package:prism/widgets/navigation_bar.dart' as nb;
import 'package:prism/widgets/wall_filter_sheet.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ScrollController controller;
  static const Duration duration = Duration(milliseconds: 300);
  static const Curve curve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    logger.d('App init done.');
  }

  void _fabAction() {
    // context.read<ThemeController>().setDarkIsTrueBlack(false);
    context.read<ThemeController>().setSchemeIndex(
          (context.read<ThemeController>().schemeIndex + 1) % 40,
        );
  }

  String appBarText(int index) {
    switch (index) {
      case 0:
        return 'Walls';
      case 1:
        return 'Setups';
      case 2:
        return 'Notifications';
      case 3:
        return 'Profile';
      default:
        return 'Walls';
    }
  }

  @override
  void didChangeDependencies() {
    locator<ToastController>().init(context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final double _appBarHeight =
        kToolbarHeight + MediaQuery.of(context).padding.top;
    const double _bottomBarHeight = 80;
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
          body: Stack(
            children: [
              AnimatedPositioned(
                top:
                    context.watch<HideController>().hidden ? -_appBarHeight : 0,
                child: AnimatedOpacity(
                  opacity: context.watch<HideController>().hidden ? 0 : 1,
                  duration: duration,
                  curve: curve,
                  child: SizedBox(
                    height: _appBarHeight,
                    width: MediaQuery.of(context).size.width,
                    child: AppBar(
                      title: Text(
                        appBarText(tabsRouter.activeIndex),
                      ),
                      actions: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.search),
                        ),
                        IconButton(
                          onPressed: () {
                            if (tabsRouter.activeIndex == 0) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                routeSettings:
                                    const RouteSettings(name: '/filter_sheet'),
                                builder: (context) => const WallFilterSheet(),
                              ).then((value) {
                                if (value) {
                                  context
                                      .read<WallHavenController>()
                                      .clearSearchResults();
                                  context
                                      .read<WallHavenController>()
                                      .getSearchResults();
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.filter_list),
                        ),
                      ],
                    ),
                  ),
                ),
                duration: duration,
                curve: curve,
              ),
              FadeTransition(
                  opacity: animation,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    padding: EdgeInsets.only(
                        top: context.watch<HideController>().hidden
                            ? 0
                            : _appBarHeight),
                    child: child,
                  )),
              AnimatedPositioned(
                duration: duration,
                curve: curve,
                bottom: context.watch<HideController>().hidden
                    ? -_bottomBarHeight
                    : 0,
                child: AnimatedOpacity(
                  opacity: context.watch<HideController>().hidden ? 0 : 1,
                  duration: duration,
                  curve: curve,
                  child: SizedBox(
                    height: _bottomBarHeight,
                    width: MediaQuery.of(context).size.width,
                    child: nb.NavigationBar(
                      selectedIndex: tabsRouter.activeIndex,
                      onDestinationSelected: (value) async {
                        tabsRouter.setActiveIndex(value);
                        setState(() {});
                        switch (value) {
                          case 0:
                            if (context
                                        .read<WallHavenController>()
                                        .wallSearch ==
                                    null ||
                                context
                                        .read<WallHavenController>()
                                        .wallSearch
                                        ?.isEmpty ==
                                    true) {
                              await context
                                  .read<WallHavenController>()
                                  .getSearchResults();
                            }
                            break;
                          case 1:
                            if (context.read<SetupController>().setupSearch ==
                                    null ||
                                context
                                        .read<SetupController>()
                                        .setupSearch
                                        ?.isEmpty ==
                                    true) {
                              await context
                                  .read<SetupController>()
                                  .getSearchResults();
                            }
                            break;
                          default:
                        }
                      },
                      backgroundColor: Theme.of(context)
                          .bottomNavigationBarTheme
                          .backgroundColor,
                      labelBehavior:
                          nb.NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: const [
                        nb.NavigationDestination(
                          selectedIcon: Icon(Icons.image),
                          icon: Icon(Icons.image_outlined),
                          label: 'Walls',
                        ),
                        nb.NavigationDestination(
                          selectedIcon: Icon(Icons.imagesearch_roller),
                          icon: Icon(Icons.imagesearch_roller_outlined),
                          label: 'Setups',
                        ),
                        nb.NavigationDestination(
                          selectedIcon: Icon(Icons.notifications),
                          icon: Icon(Icons.notifications_outlined),
                          label: 'Notifications',
                        ),
                        nb.NavigationDestination(
                          selectedIcon: Icon(Icons.person),
                          icon: Icon(Icons.person_outlined),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: context.watch<HideController>().hidden
              ? null
              : AnimatedContainer(
                  duration: duration,
                  curve: curve,
                  padding: EdgeInsets.only(
                      bottom: context.watch<HideController>().hidden
                          ? 0
                          : _bottomBarHeight),
                  child: FloatingActionButton(
                    elevation: 10,
                    onPressed: _fabAction,
                    tooltip: 'Fab',
                    child: const Icon(Icons.shuffle),
                  ),
                ),
        );
      },
    );
  }
}
