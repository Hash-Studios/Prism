import 'dart:async';
import 'dart:io' show Platform;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the one notification preferences sheet, shared by the inbox and Settings.
Future<void> showNotificationSettingsSheet(BuildContext context) {
  return showPrismSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const NotificationSettingsSheet(),
  );
}

/// The operating system notification permission, behind one seam so the sheet can be tested.
class NotificationPermissionGateway {
  const NotificationPermissionGateway();

  FirebaseMessaging get messaging => FirebaseMessaging.instance;

  Future<bool> isGranted() async {
    final NotificationSettings settings = await messaging.getNotificationSettings();
    return _isAllowed(settings.authorizationStatus);
  }

  Future<bool> request() async {
    final NotificationSettings settings = await messaging.requestPermission();
    return _isAllowed(settings.authorizationStatus);
  }

  Future<void> openSystemSettings() async {
    if (Platform.isIOS) {
      await launchUrl(Uri.parse('app-settings:'));
      return;
    }
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.openAppNotificationSettings();
  }

  static bool _isAllowed(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional;
}

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key, this.permissions = const NotificationPermissionGateway()});

  final NotificationPermissionGateway permissions;

  @override
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> with WidgetsBindingObserver {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  late bool _wotd = _settingsLocal.get<bool>(PersistenceKeys.notifWotd, defaultValue: true);
  late bool _followers = _readPref(NotificationPrefKeys.followers);
  late bool _posts = _readPref(NotificationPrefKeys.posts);
  late bool _recommendations = _readPref(NotificationPrefKeys.recommendations);
  late bool _streakReminders = _readPref(NotificationPrefKeys.streakReminders);

  bool? _permissionGranted;

  bool _readPref(String key) => _settingsLocal.get<bool>(key, defaultValue: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    bool granted;
    try {
      granted = await widget.permissions.isGranted();
    } catch (_) {
      return;
    }
    if (mounted) setState(() => _permissionGranted = granted);
  }

  /// Returns whether notifications may be delivered, asking the system once if they are off.
  Future<bool> _ensurePermission() async {
    if (_permissionGranted == true) return true;
    bool granted;
    try {
      granted = await widget.permissions.isGranted() || await widget.permissions.request();
    } catch (_) {
      return true;
    }
    if (mounted) setState(() => _permissionGranted = granted);
    if (!granted) toasts.error('Notifications are off. Turn them on in system settings first.');
    return granted;
  }

  /// Applies a switch change. Turning a switch on first makes sure the system allows notifications. A guest can
  /// still turn a signed-in switch off on this device.
  Future<void> _change(bool value, Future<void> Function() change, {bool needsSignIn = false}) async {
    if (value && needsSignIn && !app_state.prismUser.loggedIn) {
      analytics.track(
        const NotificationActionBlockedEvent(
          action: AnalyticsActionValue.notificationSettingsOpened,
          reason: AnalyticsReasonValue.notSignedIn,
        ),
      );
      toasts.error('Sign in to change this setting.');
      return;
    }
    if (value && !await _ensurePermission()) return;
    await change();
  }

  Widget _permissionBanner() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PrismRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(PrismSpace.sm, PrismSpace.xs, PrismSpace.xs, PrismSpace.xs),
        child: Row(
          children: <Widget>[
            Icon(Icons.notifications_off_outlined, color: cs.onSurface),
            const SizedBox(width: PrismSpace.sm),
            Expanded(child: Text('Notifications are off for Prism.', style: PrismTextStyles.body(context))),
            PrismButton(
              label: 'Open settings',
              variant: PrismButtonVariant.ghost,
              size: PrismButtonSize.compact,
              onPressed: () => widget.permissions.openSystemSettings(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool needsSignIn = false,
  }) {
    final bool needsSignInToTurnOn = needsSignIn && !app_state.prismUser.loggedIn && !value;
    return PrismSwitchRow(
      icon: icon,
      title: title,
      subtitle: needsSignInToTurnOn ? 'Sign in to turn on' : subtitle,
      value: value,
      onChanged: needsSignInToTurnOn ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrismSheetBody(
      title: 'Notification preferences',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_permissionGranted == false) ...<Widget>[_permissionBanner(), const SizedBox(height: PrismSpace.sm)],
          PrismGroup(
            children: <Widget>[
              _toggle(
                icon: Icons.wb_sunny_rounded,
                title: 'Wall of the Day',
                subtitle: 'A daily wallpaper pick.',
                value: _wotd,
                onChanged: (bool value) => _change(value, () => _setWotd(value)),
              ),
              _toggle(
                icon: Icons.person_add_rounded,
                title: 'Followers',
                subtitle: 'Alerts when someone new follows you.',
                value: _followers,
                needsSignIn: true,
                onChanged: (bool value) => _change(value, () => _setFollowers(value), needsSignIn: true),
              ),
              _toggle(
                icon: Icons.photo_library_rounded,
                title: 'Posts',
                subtitle: 'Alerts when creators you follow share new work.',
                value: _posts,
                needsSignIn: true,
                onChanged: _followers
                    ? (bool value) => _change(value, () => _setPosts(value), needsSignIn: true)
                    : null,
              ),
              _toggle(
                icon: Icons.lightbulb_rounded,
                title: 'Recommendations',
                subtitle: 'Tips, news and wallpaper picks from Prism.',
                value: _recommendations,
                onChanged: (bool value) => _change(value, () => _setRecommendations(value)),
              ),
              _toggle(
                icon: Icons.local_fire_department_rounded,
                title: 'Streak reminders',
                subtitle: 'Evening heads-up around 8 PM if your login streak is about to break.',
                value: _streakReminders,
                needsSignIn: true,
                onChanged: (bool value) => _change(value, () => _setStreakReminders(value), needsSignIn: true),
              ),
            ],
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
          widget.permissions.messaging,
          userTopic,
          sourceTag: 'notification.settings.followers.enable.user_topic',
        );
      }
      final String? followersTopic = followersTopicFromEmail(app_state.prismUser.email);
      if (followersTopic == null) return;
      await subscribeToTopicSafely(
        widget.permissions.messaging,
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
          widget.permissions.messaging,
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
        widget.permissions.messaging,
        app_state.prismUser.following,
        subscribed: value,
        sourceTag: value ? 'notification.settings.posts.enable' : 'notification.settings.posts.disable',
      ),
    );
  }

  Future<void> _setWotd(bool value) async {
    await _settingsLocal.set(PersistenceKeys.notifWotd, value);
    setState(() => _wotd = value);
    await setWotdTopics(
      widget.permissions.messaging,
      _settingsLocal,
      subscribed: value,
      sourceTag: value
          ? 'notification.settings.wall_of_the_day.enable'
          : 'notification.settings.wall_of_the_day.disable',
    );
  }

  Future<void> _setRecommendations(bool value) async {
    await _settingsLocal.set(NotificationPrefKeys.recommendations, value);
    setState(() => _recommendations = value);
    analytics.track(
      NotificationPreferenceChangedEvent(preference: NotificationPreferenceValue.recommendations, value: value),
    );
    unawaited(FcmTokenService.instance.saveMarketingPushes(userId: app_state.prismUser.id, enabled: value));
    if (value) {
      await subscribeToTopicSafely(
        widget.permissions.messaging,
        'recommendations',
        sourceTag: 'notification.settings.recommendations.enable',
      );
    } else {
      await unsubscribeFromTopicSafely(
        widget.permissions.messaging,
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
