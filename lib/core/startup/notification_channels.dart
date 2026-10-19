import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannelSpec {
  const NotificationChannelSpec(
    this.id,
    this.name,
    this.description, {
    this.playSound = true,
    this.importance = Importance.defaultImportance,
  });

  final String id;
  final String name;
  final String description;
  final bool playSound;
  final Importance importance;
}

/// Every channel id the server sends to, plus `downloads`. The server sets `priority: high` on the ones marked
/// high here, so the channel must allow a heads-up banner or the setting has no effect.
List<NotificationChannelSpec> notificationChannelSpecs(AppLocalizations l10n) => <NotificationChannelSpec>[
  NotificationChannelSpec(
    'followers',
    l10n.notifChannelFollowers,
    l10n.notifChannelFollowersDescription,
    importance: Importance.high,
  ),
  NotificationChannelSpec(
    'recommendations',
    l10n.notifChannelRecommendations,
    l10n.notifChannelRecommendationsDescription,
  ),
  NotificationChannelSpec('posts', l10n.notifChannelPosts, l10n.notifChannelPostsDescription),
  NotificationChannelSpec(
    'downloads',
    l10n.notifChannelDownloads,
    l10n.notifChannelDownloadsDescription,
    playSound: false,
  ),
  NotificationChannelSpec(
    'wall_of_the_day',
    l10n.notifChannelWotd,
    l10n.notifChannelWotdDescription,
    importance: Importance.high,
  ),
  NotificationChannelSpec(
    'drops',
    l10n.notifChannelDrops,
    l10n.notifChannelDropsDescription,
    importance: Importance.high,
  ),
  NotificationChannelSpec(
    'streak_reminder',
    l10n.notifChannelStreaks,
    l10n.notifChannelStreaksDescription,
    importance: Importance.high,
  ),
  NotificationChannelSpec(
    'moderation',
    l10n.notifChannelModeration,
    l10n.notifChannelModerationDescription,
    importance: Importance.high,
  ),
  NotificationChannelSpec(
    'gifts',
    l10n.notifChannelGifts,
    l10n.notifChannelGiftsDescription,
    importance: Importance.high,
  ),
  NotificationChannelSpec('draw', l10n.notifChannelDraw, l10n.notifChannelDrawDescription, importance: Importance.high),
];

/// Creates the channels on Android. Android keeps the name and importance of a channel that exists, so a new
/// importance reaches new installs only.
Future<void> createNotificationChannels(FlutterLocalNotificationsPlugin plugin, AppLocalizations l10n) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final AndroidFlutterLocalNotificationsPlugin? android = plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;
  await android.createNotificationChannelGroup(
    AndroidNotificationChannelGroup(
      'notifications',
      l10n.notifChannelGroup,
      description: l10n.notifChannelGroupDescription,
    ),
  );
  for (final NotificationChannelSpec spec in notificationChannelSpecs(l10n)) {
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        spec.id,
        spec.name,
        description: spec.description,
        playSound: spec.playSound,
        importance: spec.importance,
      ),
    );
  }
}
