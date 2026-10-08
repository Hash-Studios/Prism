import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/rating/rate_prompt_sheet.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/session/data/app_session_tracker.dart';
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

enum RatePromptTrigger { wallpaperSet, download }

typedef _ReadSetting = T Function<T>(String key, T defaultValue);
typedef _WriteSetting = Future<void> Function(String key, Object? value);

const String _iosReviewUrl = 'https://apps.apple.com/app/id1405860595?action=write-review';
const String _androidReviewUrl = 'market://details?id=com.hash.prism';
const String _androidReviewWebUrl = 'https://play.google.com/store/apps/details?id=com.hash.prism';

/// Asks a happy user for a store review, at most a few times and only after real use.
///
/// Step 1 is a calm question. "Yes" opens the store review page. "Not really" opens Report a problem.
class RatePromptService {
  RatePromptService({
    _ReadSetting? read,
    _WriteSetting? write,
    DateTime Function()? clock,
    DateTime Function()? firstLaunchAt,
    String Function()? appVersion,
    TargetPlatform Function()? platform,
    bool Function()? claimStartupSlot,
    Future<RatePromptChoice> Function(BuildContext context)? showQuestion,
    Future<bool> Function(Uri uri)? launch,
    Future<void> Function(BuildContext context)? openReportProblem,
    Future<void> Function(AnalyticsEvent event)? track,
  }) : _read = read ?? _defaultRead,
       _write = write ?? _defaultWrite,
       _clock = clock ?? DateTime.now,
       _firstLaunchAt = firstLaunchAt ?? (() => AppSessionTracker.instance.firstLaunchAt),
       _appVersion = appVersion ?? (() => app_state.currentAppVersion),
       _platform = platform ?? (() => defaultTargetPlatform),
       _claimStartupSlot = claimStartupSlot ?? StartupModalSlot.tryClaim,
       _showQuestion = showQuestion ?? showRatePromptSheet,
       _launch = launch ?? _defaultLaunch,
       _openReportProblem = openReportProblem ?? _defaultOpenReportProblem,
       _track = track ?? analytics.track;

  static final RatePromptService instance = RatePromptService();

  static const int minActions = 3;
  static const Duration minAppAge = Duration(days: 5);
  static const Duration minGapBetweenAsks = Duration(days: 14);
  static const int maxAsksPerVersion = 3;

  static const String actionsKey = 'rate_prompt.actions';
  static const String lastAskAtKey = 'rate_prompt.last_ask_at';
  static const String askVersionKey = 'rate_prompt.ask_version';
  static const String asksInVersionKey = 'rate_prompt.asks_in_version';
  static const String doneKey = 'rate_prompt.done';

  final _ReadSetting _read;
  final _WriteSetting _write;
  final DateTime Function() _clock;
  final DateTime Function() _firstLaunchAt;
  final String Function() _appVersion;
  final TargetPlatform Function() _platform;
  final bool Function() _claimStartupSlot;
  final Future<RatePromptChoice> Function(BuildContext context) _showQuestion;
  final Future<bool> Function(Uri uri) _launch;
  final Future<void> Function(BuildContext context) _openReportProblem;
  final Future<void> Function(AnalyticsEvent event) _track;

  /// Call after a wallpaper was set or downloaded. It counts the action, then asks only when every rule passes.
  Future<void> maybePrompt(BuildContext context, RatePromptTrigger trigger) async {
    try {
      final int actions = _read<int>(actionsKey, 0) + 1;
      await _write(actionsKey, actions);
      if (!_canAsk(actions) || !context.mounted) return;
      if (!_claimStartupSlot()) return;

      final DateTime now = _clock();
      final String version = _appVersion();
      final int asksInVersion = _read<String>(askVersionKey, '') == version ? _read<int>(asksInVersionKey, 0) : 0;
      await _write(lastAskAtKey, now.toUtc().toIso8601String());
      await _write(askVersionKey, version);
      await _write(asksInVersionKey, asksInVersion + 1);
      unawaited(_track(RatePromptShownEvent(trigger: trigger.name)));

      if (!context.mounted) return;
      final RatePromptChoice choice = await _showQuestion(context);
      unawaited(_track(RatePromptResultEvent(result: _resultName(choice))));
      switch (choice) {
        case RatePromptChoice.yes:
          await _write(doneKey, true);
          await _openStoreReview();
        case RatePromptChoice.notReally:
          if (context.mounted) await _openReportProblem(context);
        case RatePromptChoice.dismissed:
          break;
      }
    } catch (error, stackTrace) {
      logger.w('Rate prompt failed.', tag: 'RatePrompt', error: error, stackTrace: stackTrace);
    }
  }

  bool _canAsk(int actions) {
    if (_read<bool>(doneKey, false)) return false;
    if (actions < minActions) return false;
    final DateTime now = _clock();
    if (now.difference(_firstLaunchAt()) < minAppAge) return false;
    final DateTime? lastAsk = DateTime.tryParse(_read<String>(lastAskAtKey, ''));
    if (lastAsk != null && now.difference(lastAsk) < minGapBetweenAsks) return false;
    final String version = _appVersion();
    if (_read<String>(askVersionKey, '') == version && _read<int>(asksInVersionKey, 0) >= maxAsksPerVersion) {
      return false;
    }
    return true;
  }

  String _resultName(RatePromptChoice choice) => switch (choice) {
    RatePromptChoice.yes => 'yes',
    RatePromptChoice.notReally => 'not_really',
    RatePromptChoice.dismissed => 'dismissed',
  };

  Future<void> _openStoreReview() async {
    if (_platform() == TargetPlatform.iOS) {
      await _launch(Uri.parse(_iosReviewUrl));
      return;
    }
    bool opened = false;
    try {
      opened = await _launch(Uri.parse(_androidReviewUrl));
    } catch (_) {
      opened = false;
    }
    if (!opened) await _launch(Uri.parse(_androidReviewWebUrl));
  }

  static T _defaultRead<T>(String key, T defaultValue) {
    return getIt<SettingsLocalDataSource>().get<T>(key, defaultValue: defaultValue);
  }

  static Future<void> _defaultWrite(String key, Object? value) => getIt<SettingsLocalDataSource>().set(key, value);

  static Future<bool> _defaultLaunch(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  static Future<void> _defaultOpenReportProblem(BuildContext context) =>
      showReportProblemSheet(context, source: 'rate_prompt');
}
