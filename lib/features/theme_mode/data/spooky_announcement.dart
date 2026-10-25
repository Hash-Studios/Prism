import 'dart:async';

import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/theme_mode/views/widgets/spooky_decor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';

const String spookyAnnouncementId = 'local_spooky_theme_2026';
const String spookyAnnouncedKey = 'spookyThemeAnnounced2026';
const String spookyAnnouncementPendingKey = 'spookyThemeAnnouncementPending2026';

Future<bool>? _announcementInFlight;

/// Records an app update and retries an eligible announcement until its inbox write succeeds.
/// Returns true when this launch detected an app update.
Future<bool> checkSpookyAnnouncementOnAppUpdate({
  required String currentVersion,
  required String currentBuild,
  required SettingsLocalDataSource settings,
  required Future<bool> Function() announce,
  DateTime? now,
}) async {
  final String? lastSeenVersion = settings.get<Object?>('lastSeenVersion') as String?;
  final String? lastSeenBuild = settings.get<Object?>('lastSeenBuildVersion') as String?;
  final bool updated =
      lastSeenVersion != null &&
      (lastSeenVersion != currentVersion || lastSeenBuild == null || lastSeenBuild != currentBuild);
  if (updated) await settings.set(spookyAnnouncementPendingKey, true);
  await settings.set('lastSeenVersion', currentVersion);
  await settings.set('lastSeenBuildVersion', currentBuild);
  if (!settings.get<bool>(spookyAnnouncementPendingKey, defaultValue: false)) return updated;
  if (!isSpookySeason(now)) {
    await settings.delete(spookyAnnouncementPendingKey);
    return updated;
  }

  try {
    final bool announced = await announce();
    if (announced || settings.get<bool>(spookyAnnouncedKey, defaultValue: false)) {
      await settings.delete(spookyAnnouncementPendingKey);
    }
  } catch (error, stackTrace) {
    logger.w('Spooky theme announcement failed.', error: error, stackTrace: stackTrace);
  }
  return updated;
}

/// Returns true when it announced. Runs at most once per install.
Future<bool> announceSpookyTheme({
  required DateTime now,
  required AppLocalizations l10n,
  required SettingsLocalDataSource settings,
  required NotificationsLocalDataSource inbox,
  required Future<void> Function(String title, String body) showPush,
}) async {
  final Future<bool>? inFlight = _announcementInFlight;
  if (inFlight != null) return inFlight;
  final Future<bool> operation = _announceSpookyTheme(
    now: now,
    l10n: l10n,
    settings: settings,
    inbox: inbox,
    showPush: showPush,
  );
  _announcementInFlight = operation;
  try {
    return await operation;
  } finally {
    _announcementInFlight = null;
  }
}

Future<bool> _announceSpookyTheme({
  required DateTime now,
  required AppLocalizations l10n,
  required SettingsLocalDataSource settings,
  required NotificationsLocalDataSource inbox,
  required Future<void> Function(String title, String body) showPush,
}) async {
  if (!isSpookySeason(now) || settings.get<bool>(spookyAnnouncedKey, defaultValue: false)) return false;
  final String ownerId = inbox.ownerId;
  final int ownerGeneration = inbox.ownerGeneration;
  await inbox.upsertAll(<InAppNotificationEntity>[
    InAppNotificationEntity(
      id: spookyAnnouncementId,
      title: l10n.spookyAnnouncementTitle,
      body: l10n.spookyAnnouncementBody,
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
  await settings.set(spookyAnnouncedKey, true);
  if (inbox.ownerId != ownerId || inbox.ownerGeneration != ownerGeneration) {
    await settings.delete(spookyAnnouncedKey);
    return false;
  }
  if (settings.get<bool>(NotificationPrefKeys.recommendations, defaultValue: true)) {
    try {
      await showPush(l10n.spookyAnnouncementTitle, l10n.spookyAnnouncementBody);
    } catch (error, stackTrace) {
      logger.w('Spooky theme push failed.', error: error, stackTrace: stackTrace);
    }
  }
  return true;
}
