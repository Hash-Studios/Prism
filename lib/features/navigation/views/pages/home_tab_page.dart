import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/popup/changelog_pop_up.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/data/favourites_sync_service.dart';
import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/usecases/fetch_wall_of_the_day_usecase.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quick_actions/quick_actions.dart';

const int _homeTabIndex = 0;
const int _collectionTabIndex = 3;
const String _wallOfTheDayShortcut = 'Wall_of_the_Day';

@visibleForTesting
int? quickActionTabIndex(String shortcutType) => switch (shortcutType) {
  'Personalized_Feed' => _homeTabIndex,
  'Collections' => _collectionTabIndex,
  _ => null,
};

@visibleForTesting
List<ShortcutItem> prismShortcutItems({required bool android}) => <ShortcutItem>[
  ShortcutItem(type: 'Personalized_Feed', localizedTitle: 'For You', icon: android ? '@drawable/ic_feed' : null),
  ShortcutItem(type: 'Collections', localizedTitle: 'Collections', icon: android ? '@drawable/ic_collections' : null),
  ShortcutItem(type: 'Downloads', localizedTitle: 'Downloads', icon: android ? '@drawable/ic_downloads' : null),
  ShortcutItem(
    type: _wallOfTheDayShortcut,
    localizedTitle: 'Wall of the Day',
    icon: android ? '@drawable/ic_tile_wotd' : null,
  ),
];

@visibleForTesting
WallpaperDetailRoute wallOfTheDayRoute(WallOfTheDayEntity entity) => WallpaperDetailRoute(
  wallId: entity.wallId,
  source: entity.source == WallpaperSource.unknown ? WallpaperSource.prism : entity.source,
  thumbnailUrl: entity.thumbnailUrl.isNotEmpty ? entity.thumbnailUrl : entity.url,
);

@RoutePage()
class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool _isOnline = true;
  bool _hasHandledQuickActionInvocation = false;
  StreamSubscription<String>? _fcmTokenSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<FavouritesSyncUpdate>? _favouritesSubscription;

  Future<void> _ensureDefaultTopicSubscriptions() {
    final user = app_state.prismUser;
    return syncPushTopics(
      FirebaseMessaging.instance,
      _settingsLocal,
      userId: user.loggedIn ? user.id : '',
      email: user.email,
      premium: user.premium,
      following: user.following,
    );
  }

  void _showChangelogCheck() {
    final String? lastSeen = _settingsLocal.get<Object?>('lastSeenVersion') as String?;
    // A fresh install has no previous version: record it, but a list of fixes means nothing to a new user.
    if (lastSeen != currentAppVersion) {
      _settingsLocal.set('lastSeenVersion', currentAppVersion);
    }
    if (lastSeen != null && lastSeen != currentAppVersion) {
      showChangelog(context, () {});
    }
  }

  void _trackQuickActionInvocation(String shortcutType) {
    final AnalyticsActionValue action;
    switch (shortcutType) {
      case 'Personalized_Feed':
        action = AnalyticsActionValue.quickActionFollowFeed;
      case 'Collections':
        action = AnalyticsActionValue.quickActionCollections;
      case 'Downloads':
        action = AnalyticsActionValue.quickActionDownloads;
      case _wallOfTheDayShortcut:
        action = AnalyticsActionValue.quickActionWallOfTheDay;
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

  void _openQuickAction(String shortcutType) {
    if (!mounted) return;
    if (shortcutType == 'Downloads') {
      context.router.push(const DownloadRoute());
      return;
    }
    if (shortcutType == _wallOfTheDayShortcut) {
      unawaited(_openWallOfTheDay());
      return;
    }
    final int? tabIndex = quickActionTabIndex(shortcutType);
    if (tabIndex == null) return;
    context.router.root.popUntilRouteWithName(DashboardRoute.name);
    context.tabsRouter.setActiveIndex(tabIndex);
  }

  Future<void> _openWallOfTheDay() async {
    final Result<WallOfTheDayEntity?> result = await getIt<FetchWallOfTheDayUseCase>()(const NoParams());
    if (!mounted) return;
    final WallOfTheDayEntity? entity = result.data;
    context.router.root.popUntilRouteWithName(DashboardRoute.name);
    if (entity == null) {
      context.tabsRouter.setActiveIndex(_homeTabIndex);
      return;
    }
    unawaited(context.router.push(wallOfTheDayRoute(entity)));
  }

  Future<void> checkConnection() async {
    final bool isOnline = await getIt<ConnectivityService>().hasConnection();
    if (!mounted) return;
    setState(() => _isOnline = isOnline);
  }

  @override
  void initState() {
    super.initState();
    context.read<AdsBloc>().add(const AdsEvent.started());
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      _trackQuickActionInvocation(shortcutType);
      _openQuickAction(shortcutType);
    });

    quickActions.setShortcutItems(prismShortcutItems(android: defaultTargetPlatform == TargetPlatform.android));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showChangelogCheck();
    });
    _startFavouritesSync();
    unawaited(checkConnection());
    _connectivitySubscription = getIt<ConnectivityService>().onConnectionChange.listen((bool isOnline) {
      if (mounted) setState(() => _isOnline = isOnline);
    });
    unawaited(_startMessaging());
  }

  /// Push setup needs a Firebase app. Startup continues without one when initialisation fails.
  Future<void> _startMessaging() async {
    if (!await FirebaseInit.readyFuture || !mounted) return;
    unawaited(_ensureDefaultTopicSubscriptions());
    // On iOS the FCM token can arrive after launch, once APNs answers. Sync again then.
    _fcmTokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (_) => unawaited(_ensureDefaultTopicSubscriptions()),
    );
    // post_sign_in stores the token only at sign-in. Keep it current for users who stay signed in.
    final user = app_state.prismUser;
    if (user.loggedIn) {
      unawaited(FcmTokenService.instance.syncToken(userId: user.id));
      FcmTokenService.instance.listenForTokenRefresh(userId: user.id);
    }
  }

  void _startFavouritesSync() {
    final FavouritesSyncService sync = getIt<FavouritesSyncService>();
    _favouritesSubscription = sync.listen((FavouritesSyncUpdate update) {
      if (!mounted) return;
      context.read<FavouriteWallsBloc>().add(FavouriteWallsEvent.synced(userId: update.userId, items: update.items));
    });
    final user = app_state.prismUser;
    if (user.loggedIn) unawaited(sync.start(user.id));
  }

  @override
  void dispose() {
    unawaited(_fcmTokenSubscription?.cancel());
    unawaited(_favouritesSubscription?.cancel());
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  void _openFeedSettings() {
    unawaited(openPersonalizedFeedSettingsBottomSheet(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: PrismTopAppBar(onLogoTap: _openFeedSettings),
      body: Stack(
        children: <Widget>[
          PersonalizedFeedScreen(onTuneTap: _openFeedSettings),
          ConnectivityWidget(offline: !_isOnline),
        ],
      ),
    );
  }
}
