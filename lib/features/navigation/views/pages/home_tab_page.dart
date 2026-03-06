import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/category_feed/views/pages/collection_screen.dart';
import 'package:Prism/features/category_feed/views/pages/home_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/categories_bar.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final FavoritesLocalDataSource _favoritesLocal = getIt<FavoritesLocalDataSource>();
  int page = 0;
  bool result = true;
  String shortcut = "No Action Set";
  bool _hasHandledQuickActionInvocation = false;

  void _trackQuickActionInvocation(String shortcutType) {
    final AnalyticsActionValue action;
    switch (shortcutType) {
      case 'Personalized_Feed':
        action = AnalyticsActionValue.quickActionFollowFeed;
      case 'Collections':
        action = AnalyticsActionValue.quickActionCollections;
      case 'Setups':
        action = AnalyticsActionValue.quickActionSetups;
      case 'AI_Wallpapers':
        action = AnalyticsActionValue.quickActionAiWallpapers;
      case 'Downloads':
        action = AnalyticsActionValue.quickActionDownloads;
      default:
        action = AnalyticsActionValue.quickActionUnknown;
    }
    analytics.track(
      QuickActionInvokedEvent(
        action: action,
        launchState: _hasHandledQuickActionInvocation ? LaunchStateValue.foreground : LaunchStateValue.initialLaunch,
      ),
    );
    _hasHandledQuickActionInvocation = true;
  }

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
    if (app_state.prismUser.loggedIn) {
      final String userId = app_state.prismUser.id;
      if (_favoritesLocal.isSeeded(userId)) {
        return;
      }
      final value = await context.favouriteWallsAdapter(listen: false).getDataBase();
      if (value != null && value.isNotEmpty) {
        for (final element in value) {
          await _favoritesLocal.setWallFavourite(userId, element.id, true);
        }
      }
      await _favoritesLocal.setSeeded(userId, true);
    }
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    context.read<AdsBloc>().add(const AdsEvent.started());
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      _trackQuickActionInvocation(shortcutType);
      setState(() {
        shortcut = shortcutType;
      });
      if (shortcutType == 'Personalized_Feed') {
        logger.d('Personalized_Feed');
        tabController!.animateTo(0);
      } else if (shortcutType == 'Collections') {
        logger.d('Collections');
        tabController!.animateTo(2);
      } else if (shortcutType == 'Setups') {
        logger.d('Setups');
        final tabsRouter = AutoTabsRouter.of(context);
        tabsRouter.setActiveIndex(2);
      } else if (shortcutType == 'Downloads') {
        logger.d('Downloads');
        context.router.push(const DownloadRoute());
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'Personalized_Feed', localizedTitle: 'For You', icon: '@drawable/ic_feed'),
      const ShortcutItem(type: 'Collections', localizedTitle: 'Collections', icon: '@drawable/ic_collections'),
      const ShortcutItem(type: 'Setups', localizedTitle: 'Setups', icon: '@drawable/ic_setups'),
      const ShortcutItem(type: 'Downloads', localizedTitle: 'Downloads', icon: '@drawable/ic_downloads'),
    ]);
    saveFavToLocal();
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
            tabs: [
              Tab(icon: Icon(JamIcons.users, color: Theme.of(context).colorScheme.secondary)),
              Tab(icon: Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary)),
              Tab(icon: Icon(JamIcons.pictures, color: Theme.of(context).colorScheme.secondary)),
            ],
          ),
        ),
        body: Stack(
          children: <Widget>[
            TabBarView(
              controller: tabController,
              children: const <Widget>[PersonalizedFeedScreen(), HomeScreen(), CollectionScreen()],
            ),
            if (!result) ConnectivityWidget() else Container(),
          ],
        ),
      ),
    );
  }
}
