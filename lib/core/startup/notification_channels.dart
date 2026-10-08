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
const List<NotificationChannelSpec> notificationChannelSpecs = <NotificationChannelSpec>[
  NotificationChannelSpec(
    'followers',
    'Followers',
    'Get notifications for new followers.',
    importance: Importance.high,
  ),
  NotificationChannelSpec('recommendations', 'Recommendations', 'Get notifications for recommendations from Prism.'),
  NotificationChannelSpec('posts', 'Posts', 'Get notifications for posts from artists you follow.'),
  NotificationChannelSpec(
    'downloads',
    'Downloads',
    'Get notifications for download progress of wallpapers.',
    playSound: false,
  ),
  NotificationChannelSpec(
    'wall_of_the_day',
    'Wall of the Day',
    'Daily featured wallpaper notification at 9 AM.',
    importance: Importance.high,
  ),
  NotificationChannelSpec(
    'streak_reminder',
    'Streak reminders',
    '8 PM reminder to keep your login streak alive.',
    importance: Importance.high,
  ),
  NotificationChannelSpec(
    'moderation',
    'Moderation',
    'Reports and review requests for Prism admins.',
    importance: Importance.high,
  ),
];

/// Creates the channels on Android. Android keeps the name and importance of a channel that exists, so a new
/// importance reaches new installs only.
Future<void> createNotificationChannels(FlutterLocalNotificationsPlugin plugin) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final AndroidFlutterLocalNotificationsPlugin? android = plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;
  await android.createNotificationChannelGroup(
    const AndroidNotificationChannelGroup('notifications', 'Notifications', description: 'All Prism Notifications'),
  );
  for (final NotificationChannelSpec spec in notificationChannelSpecs) {
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
