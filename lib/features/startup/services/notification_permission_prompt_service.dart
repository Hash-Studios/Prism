import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

class NotificationPermissionPromptService {
  NotificationPermissionPromptService._();

  static final NotificationPermissionPromptService instance = NotificationPermissionPromptService._();

  static const String _promptedPrefKey = 'notificationPermissionPromptedV1';
  static const String _wotdSubscribedPrefKey = 'subscribedToWotd';
  SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();

  Future<void> maybePromptAfterValueAction(BuildContext context, {required String sourceTag}) async {
    if (!_settings.isOpen || !context.mounted) {
      return;
    }
    final bool alreadyPrompted = _settings.get<bool>(_promptedPrefKey, defaultValue: false);
    if (alreadyPrompted) {
      return;
    }

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final NotificationSettings current = await messaging.getNotificationSettings();
    if (current.authorizationStatus == AuthorizationStatus.authorized ||
        current.authorizationStatus == AuthorizationStatus.provisional) {
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

    if (current.authorizationStatus == AuthorizationStatus.denied) {
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

    final NotificationSettings requested = await messaging.requestPermission(provisional: true);
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
    final bool wantsWotd = _settings.get<bool>('streakReminderSubscriber', defaultValue: true);
    if (wantsWotd) {
      subscribedToWotd = await subscribeToTopicSafely(messaging, 'wall_of_the_day', sourceTag: '$sourceTag.wotd');
      if (subscribedToWotd) {
        await _settings.set(_wotdSubscribedPrefKey, true);
      }
    }

    if (app_state.prismUser.loggedIn) {
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

  AnalyticsReasonValue _reasonFromAuthorizationStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.denied:
        return AnalyticsReasonValue.userCancelled;
      case AuthorizationStatus.notDetermined:
        return AnalyticsReasonValue.unknown;
      default:
        return AnalyticsReasonValue.unknown;
    }
  }
}
