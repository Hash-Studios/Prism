import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/session/data/app_session_tracker.dart';
import 'package:Prism/logger/logger.dart';
import 'package:in_app_review/in_app_review.dart';

enum RatePromptTrigger { wallpaperSet, download, favourite, aiWallpaperSaved }

typedef _ReadSetting = T Function<T>(String key, T defaultValue);
typedef _WriteSetting = Future<void> Function(String key, Object? value);

/// Asks for a store review with the native Play and App Store card only, and never asks a question first.
/// Google and Apple policy forbid review gating and custom review prompts.
class RatePromptService {
  RatePromptService({
    _ReadSetting? read,
    _WriteSetting? write,
    DateTime Function()? clock,
    DateTime Function()? firstLaunchAt,
    String Function()? appVersion,
    bool Function()? claimStartupSlot,
    Future<bool> Function()? isReviewAvailable,
    Future<void> Function()? requestReview,
    Future<void> Function(Duration duration)? wait,
    Future<void> Function(AnalyticsEvent event)? track,
  }) : _read = read ?? _defaultRead,
       _write = write ?? _defaultWrite,
       _clock = clock ?? DateTime.now,
       _firstLaunchAt = firstLaunchAt ?? (() => AppSessionTracker.instance.firstLaunchAt),
       _appVersion = appVersion ?? (() => app_state.currentAppVersion),
       _claimStartupSlot = claimStartupSlot ?? StartupModalSlot.tryClaim,
       _isReviewAvailable = isReviewAvailable ?? InAppReview.instance.isAvailable,
       _requestReview = requestReview ?? InAppReview.instance.requestReview,
       _wait = wait ?? Future<void>.delayed,
       _track = track ?? analytics.track;

  static final RatePromptService instance = RatePromptService();

  static const int minActions = 3;
  static const Duration minAppAge = Duration(days: 5);
  static const Duration failureCooldown = Duration(days: 3);
  static const Duration minGapBetweenAsks = Duration(days: 90);
  static const Duration promptDelay = Duration(seconds: 2);

  static const String actionsKey = 'rate_prompt.actions';
  static const String lastAskAtKey = 'rate_prompt.last_ask_at';
  static const String askVersionKey = 'rate_prompt.ask_version';
  static const String lastFailureAtKey = 'rate_prompt.last_failure_at';
  static const String doneKey = 'rate_prompt.done';

  final _ReadSetting _read;
  final _WriteSetting _write;
  final DateTime Function() _clock;
  final DateTime Function() _firstLaunchAt;
  final String Function() _appVersion;
  final bool Function() _claimStartupSlot;
  final Future<bool> Function() _isReviewAvailable;
  final Future<void> Function() _requestReview;
  final Future<void> Function(Duration duration) _wait;
  final Future<void> Function(AnalyticsEvent event) _track;

  /// Call after a good moment. It counts the action, then requests the native review card only when every rule passes.
  Future<void> maybePrompt(RatePromptTrigger trigger) async {
    try {
      final int actions = _read<int>(actionsKey, 0) + 1;
      await _write(actionsKey, actions);
      if (!_canAsk(actions)) return;
      if (!_claimStartupSlot()) return;

      await _write(lastAskAtKey, _clock().toUtc().toIso8601String());
      await _write(askVersionKey, _appVersion());
      unawaited(_track(RatePromptShownEvent(trigger: trigger.name)));

      await _wait(promptDelay);
      final bool available = await _isReviewAvailable();
      if (available) await _requestReview();
      unawaited(_track(RatePromptResultEvent(result: available ? 'requested' : 'unavailable')));
    } catch (error, stackTrace) {
      logger.w('Rate prompt failed.', tag: 'RatePrompt', error: error, stackTrace: stackTrace);
    }
  }

  /// Call when a wallpaper set or download fails. It pauses review asks for [failureCooldown].
  Future<void> recordFailure() async {
    try {
      await _write(lastFailureAtKey, _clock().toUtc().toIso8601String());
    } catch (error, stackTrace) {
      logger.w('Rate prompt failure not saved.', tag: 'RatePrompt', error: error, stackTrace: stackTrace);
    }
  }

  bool _canAsk(int actions) {
    if (_read<bool>(doneKey, false)) return false;
    if (actions < minActions) return false;
    final DateTime now = _clock();
    if (now.difference(_firstLaunchAt()) < minAppAge) return false;
    final DateTime? lastFailure = DateTime.tryParse(_read<String>(lastFailureAtKey, ''));
    if (lastFailure != null && now.difference(lastFailure) < failureCooldown) return false;
    final DateTime? lastAsk = DateTime.tryParse(_read<String>(lastAskAtKey, ''));
    if (lastAsk != null && now.difference(lastAsk) < minGapBetweenAsks) return false;
    if (_read<String>(askVersionKey, '') == _appVersion()) return false;
    return true;
  }

  static T _defaultRead<T>(String key, T defaultValue) {
    return getIt<SettingsLocalDataSource>().get<T>(key, defaultValue: defaultValue);
  }

  static Future<void> _defaultWrite(String key, Object? value) => getIt<SettingsLocalDataSource>().set(key, value);
}
