import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the one notification preferences sheet, shared by the inbox and Settings.
Future<void> showNotificationSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).primaryColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    sheetAnimationStyle: AnimationStyle(
      duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
      reverseDuration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      curve: PrismCurves.enter,
      reverseCurve: PrismCurves.exit,
    ),
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

  /// Matches list tile title styling used in [SettingsScreen].
  TextStyle get _listTileTitleStyle => TextStyle(
    color: Theme.of(context).colorScheme.secondary,
    fontWeight: FontWeight.w500,
    fontFamily: PrismFonts.proximaNova,
  );

  TextStyle _listTileSubtitleStyle() =>
      const TextStyle(fontSize: 12).copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.78));

  /// Applies a switch change. Turning a switch on first makes sure the system allows notifications.
  Future<void> _change(bool value, Future<void> Function() change, {bool needsSignIn = false}) async {
    if (needsSignIn && !app_state.prismUser.loggedIn) {
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
    PrismHaptics.selection();
    await change();
  }

  Widget _permissionBanner() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(color: cs.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: <Widget>[
              Icon(Icons.notifications_off_outlined, color: cs.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notifications are off for Prism.',
                  style: TextStyle(color: cs.secondary, fontFamily: PrismFonts.proximaNova),
                ),
              ),
              TextButton(
                onPressed: () => widget.permissions.openSystemSettings(),
                child: Text('Open settings', style: TextStyle(color: cs.error)),
              ),
            ],
          ),
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
  }) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      activeThumbColor: cs.error,
      secondary: Icon(icon, color: cs.secondary),
      value: value,
      title: Text(title, style: _listTileTitleStyle),
      subtitle: Text(subtitle, style: _listTileSubtitleStyle()),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = math.max(MediaQuery.sizeOf(context).height / 2.3, 380.0);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: ListView(
          physics: const ClampingScrollPhysics(),
          children: [
            Center(
              child: Container(
                height: 4,
                width: 36,
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(color: theme.hintColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Notification preferences', style: theme.textTheme.titleMedium),
            ),
            if (_permissionGranted == false) _permissionBanner(),
            _toggle(
              icon: Icons.wb_sunny_outlined,
              title: 'Wall of the Day',
              subtitle: 'A daily wallpaper pick.',
              value: _wotd,
              onChanged: (bool value) => _change(value, () => _setWotd(value)),
            ),
            _toggle(
              icon: JamIcons.user_plus,
              title: 'Followers',
              subtitle: 'Alerts when someone new follows you.',
              value: _followers,
              onChanged: (bool value) => _change(value, () => _setFollowers(value), needsSignIn: true),
            ),
            _toggle(
              icon: JamIcons.pictures,
              title: 'Posts',
              subtitle: 'Alerts when creators you follow share new work.',
              value: _posts,
              onChanged: _followers ? (bool value) => _change(value, () => _setPosts(value), needsSignIn: true) : null,
            ),
            _toggle(
              icon: JamIcons.lightbulb,
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
              onChanged: (bool value) => _change(value, () => _setStreakReminders(value), needsSignIn: true),
            ),
            const SizedBox(height: 24),
          ],
        ),
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
