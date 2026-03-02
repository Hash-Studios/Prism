import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/startup/views/widgets/tomorrow_hook_sheet.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class TomorrowHookService {
  TomorrowHookService._();
  static final TomorrowHookService instance = TomorrowHookService._();

  static const String _shownPrefKey = 'e4TomorrowHookShownV1';
  static const String _wotdSubscribedPrefKey = 'subscribedToWotd';

  Future<void> maybeRunTomorrowHookAtOnboardingDone(BuildContext context) async {
    if (!main.prefs.isOpen) {
      return;
    }
    final bool hasShown = (main.prefs.get(_shownPrefKey, defaultValue: false) as bool?) ?? false;
    if (hasShown) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    await analytics.track(const TomorrowHookViewedEvent(sourceContext: 'onboarding_done'));
    if (!context.mounted) {
      return;
    }
    final TomorrowHookAction action = await showTomorrowHookSheet(context) ?? TomorrowHookAction.notNow;
    final bool enableReminders = action == TomorrowHookAction.enableReminders;
    final String actionValue = enableReminders ? 'enable' : 'not_now';
    await analytics.track(TomorrowHookActionTappedEvent(action: actionValue));

    EventResultValue permissionResult = EventResultValue.ignored;
    AnalyticsReasonValue? permissionReason;
    bool subscribedToWotd = false;

    if (enableReminders) {
      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(provisional: true);

      final AuthorizationStatus status = settings.authorizationStatus;
      final bool permissionGranted =
          status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional;

      permissionResult = permissionGranted ? EventResultValue.success : EventResultValue.failure;
      permissionReason = permissionGranted ? null : _reasonFromAuthorizationStatus(status);

      if (permissionGranted) {
        subscribedToWotd = await subscribeToTopicSafely(
          FirebaseMessaging.instance,
          'wall_of_the_day',
          sourceTag: 'tomorrow_hook.enable.wotd',
        );
        if (subscribedToWotd) {
          await main.prefs.put(_wotdSubscribedPrefKey, true);
        }
        await _retryFollowersTopicSubscriptionIfLoggedIn();
      }
    }

    await analytics.track(
      TomorrowHookPermissionResultEvent(
        result: permissionResult,
        reason: permissionReason,
        subscribedToWotd: subscribedToWotd,
      ),
    );
    await main.prefs.put(_shownPrefKey, true);
  }

  Future<void> _retryFollowersTopicSubscriptionIfLoggedIn() async {
    if (!app_state.prismUser.loggedIn) {
      return;
    }
    final String email = app_state.prismUser.email.trim();
    if (email.isEmpty) {
      return;
    }
    final String followersTopic = email.split('@').first.trim();
    if (followersTopic.isEmpty) {
      return;
    }

    final bool subscribed = await subscribeToTopicSafely(
      FirebaseMessaging.instance,
      followersTopic,
      sourceTag: 'tomorrow_hook.enable.followers_topic_retry',
    );
    if (!subscribed) {
      logger.w(
        'Tomorrow hook: followers topic resubscribe skipped.',
        tag: 'Push',
        fields: <String, Object?>{'topic': followersTopic},
      );
    }
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
