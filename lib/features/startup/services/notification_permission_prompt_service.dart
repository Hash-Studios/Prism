import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class NotificationPermissionPromptService {
  NotificationPermissionPromptService._();

  static final NotificationPermissionPromptService instance = NotificationPermissionPromptService._();

  static const String _legacyPromptedPrefKey = 'notificationPermissionPromptedV1';
  static const String _promptedPrefKey = 'notificationPermissionPromptedV2';
  SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();

  /// Android reports denied until POST_NOTIFICATIONS is granted, even before the first ask.
  /// iOS provisional access delivers quietly with no banner, so it can still ask for full access.
  @visibleForTesting
  static bool canAsk(AuthorizationStatus status, TargetPlatform platform) =>
      status == AuthorizationStatus.notDetermined ||
      (status == AuthorizationStatus.denied && platform == TargetPlatform.android) ||
      (status == AuthorizationStatus.provisional && platform == TargetPlatform.iOS);

  /// V1 asked iOS only for provisional access. iOS checks again once to ask for full access.
  @visibleForTesting
  static bool alreadyPrompted({required bool v1, required bool v2, required TargetPlatform platform}) =>
      v2 || (v1 && platform != TargetPlatform.iOS);

  Future<void> maybePromptAfterValueAction(BuildContext context, {required String sourceTag}) async {
    if (!_settings.isOpen || !context.mounted) {
      return;
    }
    if (alreadyPrompted(
      v1: _settings.get<bool>(_legacyPromptedPrefKey, defaultValue: false),
      v2: _settings.get<bool>(_promptedPrefKey, defaultValue: false),
      platform: defaultTargetPlatform,
    )) {
      return;
    }

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final NotificationSettings current = await messaging.getNotificationSettings();
    if (current.authorizationStatus == AuthorizationStatus.authorized) {
      await _settings.set(_promptedPrefKey, true);
      final bool subscribedToWotd = await _subscribeAfterPermissionGrant(
        messaging,
        sourceTag: '$sourceTag.already_granted',
      );
      await analytics.track(
        TomorrowHookPermissionResultEvent(result: EventResultValue.success, subscribedToWotd: subscribedToWotd),
      );
      return;
    }

    if (!canAsk(current.authorizationStatus, defaultTargetPlatform)) {
      await _settings.set(_promptedPrefKey, true);
      await analytics.track(
        const TomorrowHookPermissionResultEvent(
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.userCancelled,
          subscribedToWotd: false,
        ),
      );
      return;
    }

    final NotificationSettings requested = await messaging.requestPermission();
    await _settings.set(_promptedPrefKey, true);

    final AuthorizationStatus status = requested.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional;
    bool subscribedToWotd = false;
    if (granted) {
      subscribedToWotd = await _subscribeAfterPermissionGrant(messaging, sourceTag: '$sourceTag.value_action_prompt');
    }

    await analytics.track(
      TomorrowHookPermissionResultEvent(
        result: granted ? EventResultValue.success : EventResultValue.failure,
        reason: granted ? null : _reasonFromAuthorizationStatus(status),
        subscribedToWotd: subscribedToWotd,
      ),
    );
  }

  Future<bool> _subscribeAfterPermissionGrant(FirebaseMessaging messaging, {required String sourceTag}) async {
    bool subscribedToWotd = false;
    final bool wantsWotd = _settings.get<bool>(PersistenceKeys.notifWotd, defaultValue: true);
    if (wantsWotd) {
      subscribedToWotd = await subscribeToTopicSafely(messaging, 'wall_of_the_day', sourceTag: '$sourceTag.wotd');
    }

    if (app_state.prismUser.loggedIn) {
      final String? userTopic = userTopicFromId(app_state.prismUser.id);
      if (userTopic != null) {
        await subscribeToTopicSafely(messaging, userTopic, sourceTag: '$sourceTag.user_topic');
      }
      final String? followersTopic = followersTopicFromEmail(app_state.prismUser.email);
      if (followersTopic != null) {
        final bool subscribed = await subscribeToTopicSafely(
          messaging,
          followersTopic,
          sourceTag: '$sourceTag.followers_topic',
        );
        if (!subscribed) {
          logger.w(
            'Deferred permission: followers topic subscribe skipped.',
            tag: 'Push',
            fields: <String, Object?>{'topic': followersTopic},
          );
        }
      }
    }

    return subscribedToWotd;
  }

  AnalyticsReasonValue _reasonFromAuthorizationStatus(AuthorizationStatus status) =>
      status == AuthorizationStatus.denied ? AnalyticsReasonValue.userCancelled : AnalyticsReasonValue.unknown;
}
