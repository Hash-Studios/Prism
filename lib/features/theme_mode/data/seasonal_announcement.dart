import 'dart:async';

import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/theme_mode/seasonal_themes.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';

final Map<String, Future<bool>> _announcementsInFlight = <String, Future<bool>>{};

/// Records an app update and retries a pending announcement until its inbox write succeeds. An update makes only the
/// first season in [seasons] that is in season and not yet announced pending, so one update sends at most one push.
/// Returns true when this launch detected an app update.
Future<bool> checkSeasonalAnnouncementOnAppUpdate({
  required String currentVersion,
  required String currentBuild,
  required SettingsLocalDataSource settings,
  required Future<bool> Function(SeasonalTheme season) announce,
  List<SeasonalTheme>? seasons,
  DateTime? now,
}) async {
  final List<SeasonalTheme> all = seasons ?? seasonalThemes;
  final String? lastSeenVersion = settings.get<Object?>('lastSeenVersion') as String?;
  final String? lastSeenBuild = settings.get<Object?>('lastSeenBuildVersion') as String?;
  final bool updated =
      lastSeenVersion != null &&
      (lastSeenVersion != currentVersion || lastSeenBuild == null || lastSeenBuild != currentBuild);
  if (updated) {
    final SeasonalTheme? next = all
        .where((season) => season.inSeason(now) && !settings.get<bool>(season.announcedKey, defaultValue: false))
        .firstOrNull;
    for (final SeasonalTheme season in all) {
      if (season == next) {
        await settings.set(season.pendingKey, true);
      } else {
        await settings.delete(season.pendingKey);
      }
    }
  }
  await settings.set('lastSeenVersion', currentVersion);
  await settings.set('lastSeenBuildVersion', currentBuild);

  for (final SeasonalTheme season in all) {
    if (!settings.get<bool>(season.pendingKey, defaultValue: false)) continue;
    if (!season.inSeason(now)) {
      await settings.delete(season.pendingKey);
      continue;
    }
    try {
      final bool announced = await announce(season);
      if (announced || settings.get<bool>(season.announcedKey, defaultValue: false)) {
        await settings.delete(season.pendingKey);
      }
    } catch (error, stackTrace) {
      logger.w('Seasonal theme announcement failed.', error: error, stackTrace: stackTrace);
    }
  }
  return updated;
}

/// Returns true when it announced. Runs at most once per install for each season.
Future<bool> announceSeasonalTheme({
  required SeasonalTheme season,
  required DateTime now,
  required AppLocalizations l10n,
  required SettingsLocalDataSource settings,
  required NotificationsLocalDataSource inbox,
  required Future<void> Function(String title, String body) showPush,
}) async {
  final Future<bool>? inFlight = _announcementsInFlight[season.name];
  if (inFlight != null) return inFlight;
  final Future<bool> operation = _announceSeasonalTheme(
    season: season,
    now: now,
    l10n: l10n,
    settings: settings,
    inbox: inbox,
    showPush: showPush,
  );
  _announcementsInFlight[season.name] = operation;
  try {
    return await operation;
  } finally {
    _announcementsInFlight.remove(season.name);
  }
}

Future<bool> _announceSeasonalTheme({
  required SeasonalTheme season,
  required DateTime now,
  required AppLocalizations l10n,
  required SettingsLocalDataSource settings,
  required NotificationsLocalDataSource inbox,
  required Future<void> Function(String title, String body) showPush,
}) async {
  if (!season.inSeason(now) || settings.get<bool>(season.announcedKey, defaultValue: false)) return false;
  final String ownerId = inbox.ownerId;
  final int ownerGeneration = inbox.ownerGeneration;
  await inbox.upsertAll(<InAppNotificationEntity>[
    InAppNotificationEntity(
      id: season.announcementId,
      title: season.announcementTitle(l10n),
      body: season.announcementBody(l10n),
      pageName: '',
      imageUrl: '',
      arguments: const <Object>[],
      url: '',
      createdAt: now.toUtc(),
      read: false,
      route: '/theme',
      kind: InAppNotificationKind.generic,
    ),
  ]);
  if (inbox.ownerId != ownerId || inbox.ownerGeneration != ownerGeneration) return false;
  await settings.set(season.announcedKey, true);
  if (inbox.ownerId != ownerId || inbox.ownerGeneration != ownerGeneration) {
    await settings.delete(season.announcedKey);
    return false;
  }
  if (settings.get<bool>(NotificationPrefKeys.recommendations, defaultValue: true)) {
    try {
      await showPush(season.announcementTitle(l10n), season.announcementBody(l10n));
    } catch (error, stackTrace) {
      logger.w('Seasonal theme push failed.', error: error, stackTrace: stackTrace);
    }
  }
  return true;
}
