import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key});

  @override
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  late bool _followers = _readPref(NotificationPrefKeys.followers);
  late bool _posts = _readPref(NotificationPrefKeys.posts);
  late bool _inApp = _readPref(NotificationPrefKeys.inApp);
  late bool _recommendations = _readPref(NotificationPrefKeys.recommendations);
  late bool _streakReminders = _readPref(NotificationPrefKeys.streakReminders);

  bool _readPref(String key) => _settingsLocal.get<bool>(key, defaultValue: true);

  /// Runs [change] for a signed-in user; otherwise reports the blocked action.
  Future<void> _whenSignedIn(Future<void> Function() change) async {
    if (app_state.prismUser.loggedIn) {
      await change();
      return;
    }
    analytics.track(
      const NotificationActionBlockedEvent(
        action: AnalyticsActionValue.notificationSettingsOpened,
        reason: AnalyticsReasonValue.notSignedIn,
      ),
    );
    toasts.error('Sign in to change this setting.');
  }

  @override
  Widget build(BuildContext context) {
    return PrismSheetBody(
      title: 'Notification preferences',
      scrollable: true,
      child: PrismGroup(
        children: <Widget>[
          PrismSwitchRow(
            icon: Icons.person_add_rounded,
            title: 'Followers',
            subtitle: 'Alerts when someone new follows you.',
            value: _followers,
            onChanged: (bool value) => _whenSignedIn(() => _setFollowers(value)),
          ),
          PrismSwitchRow(
            icon: Icons.photo_library_rounded,
            title: 'Posts',
            subtitle: 'Alerts when creators you follow share new work.',
            value: _posts,
            onChanged: _followers ? (bool value) => _whenSignedIn(() => _setPosts(value)) : null,
          ),
          PrismSwitchRow(
            icon: Icons.campaign_rounded,
            title: 'Prism updates',
            subtitle: 'Giveaways, contests and news inside the app.',
            value: _inApp,
            onChanged: _setInApp,
          ),
          PrismSwitchRow(
            icon: Icons.lightbulb_rounded,
            title: 'Recommendations',
            subtitle: 'Tips and wallpaper picks from Prism.',
            value: _recommendations,
            onChanged: _setRecommendations,
          ),
          PrismSwitchRow(
            icon: Icons.local_fire_department_rounded,
            title: 'Streak reminders',
            subtitle: 'A heads-up around 8 PM if your login streak is about to break.',
            value: _streakReminders,
            onChanged: (bool value) => _whenSignedIn(() => _setStreakReminders(value)),
          ),
        ],
      ),
    );
  }

  Future<void> _setFollowers(bool value) async {
    await _settingsLocal.set(NotificationPrefKeys.followers, value);
    setState(() => _followers = value);
    unawaited(FcmTokenService.instance.saveFollowerAlerts(userId: app_state.prismUser.id, enabled: value));
    analytics.track(
      NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.followers, value: value),
    );
    if (value) {
      final String? userTopic = userTopicFromId(app_state.prismUser.id);
      if (userTopic != null) {
        await subscribeToTopicSafely(
          FirebaseMessaging.instance,
          userTopic,
          sourceTag: 'notification.settings.followers.enable.user_topic',
        );
      }
      final String? followersTopic = followersTopicFromEmail(app_state.prismUser.email);
      if (followersTopic == null) return;
      await subscribeToTopicSafely(
        FirebaseMessaging.instance,
        followersTopic,
        sourceTag: 'notification.settings.followers.enable',
      );
    } else {
      await _settingsLocal.set(NotificationPrefKeys.posts, false);
      setState(() => _posts = false);
      analytics.track(
        const NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.posts, value: false),
      );
      unawaited(
        setCreatorPostsTopics(
          FirebaseMessaging.instance,
          app_state.prismUser.following,
          subscribed: false,
          sourceTag: 'notification.settings.posts.disable_from_followers',
        ),
      );
    }
  }

  Future<void> _setPosts(bool value) async {
    await _settingsLocal.set(NotificationPrefKeys.posts, value);
    setState(() => _posts = value);
    analytics.track(NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.posts, value: value));
    unawaited(
      setCreatorPostsTopics(
        FirebaseMessaging.instance,
        app_state.prismUser.following,
        subscribed: value,
        sourceTag: value ? 'notification.settings.posts.enable' : 'notification.settings.posts.disable',
      ),
    );
  }

  Future<void> _setInApp(bool value) async {
    await _settingsLocal.set(NotificationPrefKeys.inApp, value);
    setState(() => _inApp = value);
    analytics.track(NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.inApp, value: value));
  }

  Future<void> _setRecommendations(bool value) async {
    await _settingsLocal.set(NotificationPrefKeys.recommendations, value);
    setState(() => _recommendations = value);
    analytics.track(
      NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.recommendations, value: value),
    );
    if (value) {
      await subscribeToTopicSafely(
        FirebaseMessaging.instance,
        'recommendations',
        sourceTag: 'notification.settings.recommendations.enable',
      );
    } else {
      await unsubscribeFromTopicSafely(
        FirebaseMessaging.instance,
        'recommendations',
        sourceTag: 'notification.settings.recommendations.disable',
      );
    }
  }

  Future<void> _setStreakReminders(bool value) async {
    await _settingsLocal.set(NotificationPrefKeys.streakReminders, value);
    setState(() => _streakReminders = value);
    analytics.track(
      NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.streakReminders, value: value),
    );
    await CoinsService.instance.setStreakReminderPreference(value, sourceTag: 'notification.settings.streak_reminders');
  }
}
