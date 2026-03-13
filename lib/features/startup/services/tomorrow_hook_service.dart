import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/startup/views/widgets/tomorrow_hook_sheet.dart';
import 'package:flutter/material.dart';

class TomorrowHookService {
  TomorrowHookService._();
  static final TomorrowHookService instance = TomorrowHookService._();

  static const String _shownPrefKey = 'e4TomorrowHookShownV1';
  SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();

  Future<void> maybeRunTomorrowHookAtOnboardingDone(BuildContext context) async {
    if (!_settings.isOpen) {
      return;
    }
    final bool hasShown = _settings.get<bool>(_shownPrefKey, defaultValue: false);
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

    if (enableReminders) {
      await CoinsService.instance.setStreakReminderPreference(true, sourceTag: 'tomorrow_hook.enable_streak_pref');
    }

    await analytics.track(
      const TomorrowHookPermissionResultEvent(result: EventResultValue.ignored, subscribedToWotd: false),
    );
    await _settings.set(_shownPrefKey, true);
  }
}
