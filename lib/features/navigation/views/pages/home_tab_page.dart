import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/changelogPopUp.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:quick_actions/quick_actions.dart';

@RoutePage()
class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  final FavoritesLocalDataSource _favoritesLocal = getIt<FavoritesLocalDataSource>();
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  int page = 0;
  bool result = true;
  String shortcut = "No Action Set";
  bool _hasHandledQuickActionInvocation = false;
  bool _isChangelogCheckPending = true;
  int _personalizedFeedVersion = 0;

  Future<void> _ensureDefaultTopicSubscriptions() async {
    if (!_settingsLocal.get<bool>('subscribedToRecommendations', defaultValue: false)) {
      final messaging = FirebaseMessaging.instance;
      final bool recommendationsSubscribed = await subscribeToTopicSafely(
        messaging,
        'recommendations',
        sourceTag: 'home_tab.init.recommendations',
      );
      final bool postsSubscribed = await subscribeToTopicSafely(messaging, 'posts', sourceTag: 'home_tab.init.posts');
      if (recommendationsSubscribed && postsSubscribed) {
        _settingsLocal.set('subscribedToRecommendations', true);
      }
    }
  }

  void _showChangelogCheck() {
    final String? lastSeen = _settingsLocal.get<Object?>('lastSeenVersion') as String?;
    if (lastSeen != currentAppVersion) {
      showChangelog(context, () {
        if (mounted) {
          setState(() {
            _isChangelogCheckPending = false;
          });
        }
      });
      _settingsLocal.set('lastSeenVersion', currentAppVersion);
      return;
    }
    setState(() {
      _isChangelogCheckPending = false;
    });
  }

  void _trackQuickActionInvocation(String shortcutType) {
    final AnalyticsActionValue action;
    switch (shortcutType) {
      case 'Personalized_Feed':
        action = AnalyticsActionValue.quickActionFollowFeed;
      case 'Collections':
        action = AnalyticsActionValue.quickActionCollections;
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
    context.read<AdsBloc>().add(const AdsEvent.started());
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      _trackQuickActionInvocation(shortcutType);
      setState(() {
        shortcut = shortcutType;
      });
      if (shortcutType == 'Downloads') {
        logger.d('Downloads');
        context.router.push(const DownloadRoute());
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'Personalized_Feed', localizedTitle: 'For You', icon: '@drawable/ic_feed'),
      const ShortcutItem(type: 'Collections', localizedTitle: 'Collections', icon: '@drawable/ic_collections'),
      const ShortcutItem(type: 'Downloads', localizedTitle: 'Downloads', icon: '@drawable/ic_downloads'),
    ]);
    saveFavToLocal();
    checkConnection();
    unawaited(_ensureDefaultTopicSubscriptions());
  }

  @override
  Widget build(BuildContext context) {
    if (_isChangelogCheckPending) {
      Future<void>.delayed(Duration.zero).then((_) {
        if (!mounted) {
          return;
        }
        _showChangelogCheck();
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: PrismTopAppBar(
        onLogoTap: () => unawaited(
          openPersonalizedFeedSettingsBottomSheet(
            context,
            onPreferencesSaved: () {
              if (mounted) {
                setState(() => _personalizedFeedVersion += 1);
              }
            },
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          PersonalizedFeedScreen(key: ValueKey<int>(_personalizedFeedVersion)),
          if (!result) ConnectivityWidget() else Container(),
        ],
      ),
    );
  }
}
