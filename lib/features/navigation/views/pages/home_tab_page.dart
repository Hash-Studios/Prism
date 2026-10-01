import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/changelog_pop_up.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  bool _isOnline = true;
  bool _hasHandledQuickActionInvocation = false;
  StreamSubscription<String>? _fcmTokenSubscription;

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
    final bool isOnline = await getIt<ConnectivityService>().hasConnection();
    if (!mounted) return;
    setState(() => _isOnline = isOnline);
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
      if (shortcutType == 'Downloads') {
        context.router.push(const DownloadRoute());
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'Personalized_Feed', localizedTitle: 'For You', icon: '@drawable/ic_feed'),
      const ShortcutItem(type: 'Collections', localizedTitle: 'Collections', icon: '@drawable/ic_collections'),
      const ShortcutItem(type: 'Downloads', localizedTitle: 'Downloads', icon: '@drawable/ic_downloads'),
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showChangelogCheck();
    });
    unawaited(saveFavToLocal());
    unawaited(checkConnection());
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

  @override
  void dispose() {
    unawaited(_fcmTokenSubscription?.cancel());
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
          if (!_isOnline) const ConnectivityWidget(),
        ],
      ),
    );
  }
}
