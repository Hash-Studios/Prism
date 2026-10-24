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
import 'package:Prism/l10n/l10n.dart';
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
  return showPrismSheet<void>(context, builder: (_) => const NotificationSettingsSheet());
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
  late bool _drops = _readPref(NotificationPrefKeys.drops);
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
    final String permissionOffMessage = context.l10n.notifPermissionOff;
    if (_permissionGranted == true) return true;
    bool granted;
    try {
      granted = await widget.permissions.isGranted() || await widget.permissions.request();
    } catch (_) {
      return true;
    }
    if (mounted) setState(() => _permissionGranted = granted);
    if (!granted) toasts.error(permissionOffMessage);
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
      toasts.error(context.l10n.notifSignInToChange);
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
            Expanded(child: Text(context.l10n.notifPermissionOffForApp, style: PrismTextStyles.body(context))),
            PrismButton(
              label: context.l10n.notifOpenSettings,
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
      subtitle: needsSignInToTurnOn ? context.l10n.notifSignInToTurnOn : subtitle,
      value: value,
      onChanged: needsSignInToTurnOn ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrismSheetBody(
      title: context.l10n.notifPreferences,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_permissionGranted == false) ...<Widget>[_permissionBanner(), const SizedBox(height: PrismSpace.sm)],
          PrismGroup(
            children: <Widget>[
              _toggle(
                icon: Icons.wb_sunny_rounded,
                title: context.l10n.notifSettingWotd,
                subtitle: context.l10n.notifSettingWotdDescription,
                value: _wotd,
                onChanged: (bool value) => _change(value, () => _setWotd(value)),
              ),
              _toggle(
                icon: Icons.auto_awesome_rounded,
                title: context.l10n.notifSettingDrops,
                subtitle: context.l10n.notifSettingDropsDescription,
                value: _drops,
                onChanged: (bool value) => _change(value, () => _setDrops(value)),
              ),
              _toggle(
                icon: Icons.person_add_rounded,
                title: context.l10n.notifSettingFollowers,
                subtitle: context.l10n.notifSettingFollowersDescription,
                value: _followers,
                needsSignIn: true,
                onChanged: (bool value) => _change(value, () => _setFollowers(value), needsSignIn: true),
              ),
              _toggle(
                icon: Icons.photo_library_rounded,
                title: context.l10n.notifSettingPosts,
                subtitle: context.l10n.notifSettingPostsDescription,
                value: _posts,
                needsSignIn: true,
                onChanged: _followers
                    ? (bool value) => _change(value, () => _setPosts(value), needsSignIn: true)
                    : null,
              ),
              _toggle(
                icon: Icons.lightbulb_rounded,
                title: context.l10n.notifSettingRecommendations,
                subtitle: context.l10n.notifSettingRecommendationsDescription,
                value: _recommendations,
                onChanged: (bool value) => _change(value, () => _setRecommendations(value)),
              ),
              _toggle(
                icon: Icons.local_fire_department_rounded,
                title: context.l10n.notifSettingStreaks,
                subtitle: context.l10n.notifSettingStreaksDescription,
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
      final String? legacyUserTopic = userTopicFromId(app_state.prismUser.id);
      if (legacyUserTopic != null) {
        await unsubscribeFromTopicSafely(
          widget.permissions.messaging,
          legacyUserTopic,
          sourceTag: 'notification.settings.followers.enable.user_topic_cleanup',
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
        syncCreatorPostsTopicsForUser(
          widget.permissions.messaging,
          userId: app_state.prismUser.id,
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
      syncCreatorPostsTopicsForUser(
        widget.permissions.messaging,
        userId: app_state.prismUser.id,
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

  Future<void> _setDrops(bool value) async {
    await _settingsLocal.set(NotificationPrefKeys.drops, value);
    setState(() => _drops = value);
    if (value) {
      await subscribeToTopicSafely(
        widget.permissions.messaging,
        'drops',
        sourceTag: 'notification.settings.drops.enable',
      );
    } else {
      await unsubscribeFromTopicSafely(
        widget.permissions.messaging,
        'drops',
        sourceTag: 'notification.settings.drops.disable',
      );
    }
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
