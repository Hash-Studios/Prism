import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_nudge_sheet.dart';
import 'package:Prism/features/session/data/app_session_tracker.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

typedef _ProfileCompletenessSheetLauncher =
    Future<ProfileCompletenessNudgeAction?> Function(BuildContext context, {required ProfileCompletenessStatus status});

typedef _ProfileCompletenessEventTracker = Future<void> Function(AnalyticsEvent event);
typedef _ProfileCompletenessOpenEditProfile = Future<void> Function(BuildContext context);

typedef _ReadPrefValue = bool Function(String key, {bool defaultValue});
typedef _WritePrefValue = Future<void> Function(String key, bool value);

class ProfileCompletenessNudgeService {
  ProfileCompletenessNudgeService({
    _ProfileCompletenessSheetLauncher? sheetLauncher,
    _ProfileCompletenessEventTracker? trackEvent,
    _ProfileCompletenessOpenEditProfile? openEditProfile,
    _ReadPrefValue? readPrefValue,
    _WritePrefValue? writePrefValue,
    int Function()? sessionNumber,
    bool Function()? claimStartupSlot,
  }) : _sheetLauncher = sheetLauncher ?? showProfileCompletenessNudgeSheet,
       _trackEvent = trackEvent ?? analytics.track,
       _openEditProfile = openEditProfile ?? _defaultOpenEditProfile,
       _readPrefValue = readPrefValue ?? _defaultReadPrefValue,
       _writePrefValue = writePrefValue ?? _defaultWritePrefValue,
       _sessionNumber = sessionNumber ?? (() => AppSessionTracker.instance.sessionNumber),
       _claimStartupSlot = claimStartupSlot ?? StartupModalSlot.tryClaim;

  static final ProfileCompletenessNudgeService instance = ProfileCompletenessNudgeService();

  static const String _prefPrefix = 'e5ProfileCompletenessNudgeShownV1';

  /// The nudge waits until the user has opened Prism this many times.
  static const int minSessions = 3;

  final _ProfileCompletenessSheetLauncher _sheetLauncher;
  final _ProfileCompletenessEventTracker _trackEvent;
  final _ProfileCompletenessOpenEditProfile _openEditProfile;
  final _ReadPrefValue _readPrefValue;
  final _WritePrefValue _writePrefValue;
  final int Function() _sessionNumber;
  final bool Function() _claimStartupSlot;

  Future<void> maybeShowNudge(BuildContext context, {required String sourceContext}) async {
    final int session = _sessionNumber();
    if (!app_state.prismUser.loggedIn) {
      return;
    }

    final String userId = app_state.prismUser.id.trim();
    if (userId.isEmpty) {
      return;
    }

    final ProfileCompletenessStatus status = ProfileCompletenessEvaluator.evaluate(
      app_state.prismUser,
      defaultProfilePhotoUrl: app_state.defaultProfilePhotoUrl,
    );

    if (status.isComplete) {
      return;
    }

    final String prefKey = shownPrefKeyForUser(userId);
    final bool hasShown = _readPrefValue(prefKey, defaultValue: false);
    if (hasShown) {
      return;
    }

    if (session < minSessions || !_claimStartupSlot()) {
      return;
    }

    await _trackEvent(
      ProfileCompletenessNudgeViewedEvent(
        sourceContext: sourceContext,
        progressPercent: status.percent,
        missingStepsCount: status.missingSteps.length,
      ),
    );

    if (!context.mounted) {
      return;
    }

    final ProfileCompletenessNudgeAction action =
        await _sheetLauncher(context, status: status) ?? ProfileCompletenessNudgeAction.notNow;

    await _trackEvent(
      ProfileCompletenessActionTappedEvent(
        sourceContext: sourceContext,
        action: _actionName(action),
        progressPercent: status.percent,
      ),
    );

    await _writePrefValue(prefKey, true);

    if (action == ProfileCompletenessNudgeAction.completeNow && context.mounted) {
      await _openEditProfile(context);
    }
  }

  String shownPrefKeyForUser(String userId) {
    return '$_prefPrefix.${userId.trim()}';
  }

  String _actionName(ProfileCompletenessNudgeAction action) {
    switch (action) {
      case ProfileCompletenessNudgeAction.completeNow:
        return 'complete_now';
      case ProfileCompletenessNudgeAction.notNow:
        return 'not_now';
    }
  }

  static bool _defaultReadPrefValue(String key, {bool defaultValue = false}) {
    return getIt<SettingsLocalDataSource>().get<bool>(key, defaultValue: defaultValue);
  }

  static Future<void> _defaultWritePrefValue(String key, bool value) async {
    await getIt<SettingsLocalDataSource>().set(key, value);
  }

  static Future<void> _defaultOpenEditProfile(BuildContext context) async {
    await context.router.root.push(const EditProfilePanelRoute());
  }
}
