import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/category_feed/views/pages/collection_screen.dart';
import 'package:Prism/features/category_feed/views/pages/following_screen.dart';
import 'package:Prism/features/category_feed/views/pages/home_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/categories_bar.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_io/hive_io.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:quick_actions/quick_actions.dart';

TabController? tabController;

@RoutePage()
class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> with SingleTickerProviderStateMixin {
  int page = 0;
  bool result = true;
  final box = Hive.box('localFav');
  String shortcut = "No Action Set";

  Future<void> checkConnection() async {
    result = await InternetConnectionChecker.instance.hasConnection;
    if (result) {
      logger.d("Internet working as expected!");
      setState(() {});
    } else {
      logger.d("Not connected to Internet!");
      setState(() {});
    }
  }

  Future<void> saveFavToLocal() async {
    if (globals.prismUser.loggedIn) {
      final value = await context.favouriteWallsAdapter(listen: false).getDataBase();
      if (value == null || value.isEmpty) {
        return;
      }
      for (final element in value) {
        box.put(element['id'].toString(), true);
      }
      box.put('dataSaved', true);
    }
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: globals.followersTab ? 3 : 2, vsync: this);
    context.read<AdsBloc>().add(const AdsEvent.started());
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      setState(() {
        shortcut = shortcutType;
      });
      if (shortcutType == 'Follow_Feed') {
        logger.d('Follow_Feed');
        if (globals.followersTab) {
          tabController!.animateTo(1);
        }
      } else if (shortcutType == 'Collections') {
        logger.d('Collections');
        if (globals.followersTab) {
          tabController!.animateTo(2);
        } else {
          tabController!.animateTo(1);
        }
      } else if (shortcutType == 'Setups' || shortcutType == 'AI_Wallpapers') {
        logger.d('AI_Wallpapers');
        final tabsRouter = AutoTabsRouter.of(context);
        tabsRouter.setActiveIndex(2);
      } else if (shortcutType == 'Downloads') {
        logger.d('Downloads');
        context.router.push(const DownloadRoute());
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'Follow_Feed', localizedTitle: 'Feed', icon: '@drawable/ic_feed'),
      const ShortcutItem(type: 'Collections', localizedTitle: 'Collections', icon: '@drawable/ic_collections'),
      const ShortcutItem(type: 'AI_Wallpapers', localizedTitle: 'AI', icon: '@drawable/ic_setups'),
      const ShortcutItem(type: 'Downloads', localizedTitle: 'Downloads', icon: '@drawable/ic_downloads'),
    ]);
    if (box.get('dataSaved', defaultValue: false) as bool) {
    } else {
      saveFavToLocal();
    }
    checkConnection();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: tabController?.index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (tabController?.index != 0) {
          tabController?.animateTo(0);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: const PreferredSize(preferredSize: Size(double.infinity, 55), child: CategoriesBar()),
          bottom: TabBar(
            controller: tabController,
            indicatorColor: Theme.of(context).colorScheme.secondary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: globals.followersTab
                ? [
                    Tab(icon: Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary)),
                    Tab(icon: Icon(JamIcons.user_square, color: Theme.of(context).colorScheme.secondary)),
                    Tab(icon: Icon(JamIcons.pictures, color: Theme.of(context).colorScheme.secondary)),
                  ]
                : [
                    Tab(icon: Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary)),
                    Tab(icon: Icon(JamIcons.pictures, color: Theme.of(context).colorScheme.secondary)),
                  ],
          ),
        ),
        body: Stack(
          children: <Widget>[
            TabBarView(
              controller: tabController,
              children: (globals.followersTab == true)
                  ? <Widget>[
                      const HomeScreen(),
                      if (globals.prismUser.loggedIn == true)
                        const FollowingScreen()
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Spacer(),
                            Center(
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: const Text(
                                  "Please sign-in to view the latest walls from the artists you follow here.",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                googleSignInPopUp(context, () {
                                  main.RestartWidget.restartApp(context);
                                });
                              },
                              style: ButtonStyle(
                                backgroundColor: WidgetStateColor.resolveWith((states) => Colors.white),
                              ),
                              child: const SizedBox(
                                width: 60,
                                child: Text(
                                  'SIGN-IN',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFE57697),
                                    fontSize: 15,
                                    fontFamily: "Roboto",
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      const CollectionScreen(),
                    ]
                  : [const HomeScreen(), const CollectionScreen()],
            ),
            if (!result) ConnectivityWidget() else Container(),
          ],
        ),
      ),
    );
  }
}
