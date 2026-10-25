import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/theme_mode/views/widgets/spooky_decor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';

const String spookyAnnouncementId = 'local_spooky_theme_2026';
const String spookyAnnouncedKey = 'spookyThemeAnnounced2026';

/// Returns true when it announced. Runs at most once per install.
Future<bool> announceSpookyTheme({
  required DateTime now,
  required AppLocalizations l10n,
  required SettingsLocalDataSource settings,
  required NotificationsLocalDataSource inbox,
  required Future<void> Function(String title, String body) showPush,
}) async {
  if (!isSpookySeason(now) || settings.get<bool>(spookyAnnouncedKey, defaultValue: false)) return false;
  await settings.set(spookyAnnouncedKey, true);
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
  if (settings.get<bool>(NotificationPrefKeys.recommendations, defaultValue: true)) {
    try {
      await showPush(l10n.spookyAnnouncementTitle, l10n.spookyAnnouncementBody);
    } catch (error, stackTrace) {
      logger.w('Spooky theme push failed.', error: error, stackTrace: stackTrace);
    }
  }
  return true;
}
