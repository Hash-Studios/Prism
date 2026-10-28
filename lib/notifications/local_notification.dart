import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/platform/ios_widget_channel.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotification {
  // iOS permission is asked after the first download or set, in NotificationPermissionPromptService.
  @visibleForTesting
  static const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestSoundPermission: false,
    requestBadgePermission: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  // The live `_MyAppState` sets these. RestartWidget re-creates that state, and the new one replaces them.
  Future<void> Function(Map<String, dynamic> data)? onPushTap;
  VoidCallback? onForegroundPush;
  bool _listeningForPush = false;
  bool _launchHandled = false;
  LocalNotification() {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: darwinSettings,
    );
    flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final Map<String, dynamic>? data = _pushData(response.payload);
        if (data != null) unawaited(onPushTap?.call(data));
      },
    );
  }

  /// Title for the download summary notification with the supplied total count.
  @visibleForTesting
  static String downloadedTitle(int count, AppLocalizations l10n) {
    return l10n.notifDownloadedTitle(count);
  }

  /// Listens to FCM once per process. Listening from each `_MyAppState` added one more listener per restart.
  void listenForPushMessages({required Future<AppLocalizations> Function() localizations}) {
    if (_listeningForPush) return;
    _listeningForPush = true;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.data['route']?.toString() == 'wall_of_the_day') unawaited(IosWidgetChannel.reloadWallOfTheDay());
      final AppLocalizations messages = await localizations();
      await showPushNotification(message, localizations: messages);
      onForegroundPush?.call();
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) => unawaited(onPushTap?.call(message.data)));
  }

  Future<void> routeInitialMessage({FirebaseMessaging? messaging}) async {
    final RemoteMessage? message = await (messaging ?? FirebaseMessaging.instance).getInitialMessage();
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(onPushTap?.call(message.data));
    });
  }

  Future<void> fetchNotificationData() async {
    // RestartWidget re-runs this after logout, and the launch details stay the same. Handle them once.
    if (_launchHandled) return;
    _launchHandled = true;
    final NotificationAppLaunchDetails? notificationAppLaunchDetails = await flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp != true) return;
    final String? payload = notificationAppLaunchDetails?.notificationResponse?.payload;
    final Map<String, dynamic>? data = _pushData(payload);
    if (data != null) await onPushTap?.call(data);
  }

  /// Push data stored by [showPushNotification]. Older builds stored only the route string.
  static Map<String, dynamic>? _pushData(String? payload) {
    if (payload == null || payload.isEmpty || payload == 'downloadProgress') return null;
    if (payload == 'downloaded') return <String, dynamic>{'route': '/downloads'};
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        if (decoded['kind'] == 'downloaded') return <String, dynamic>{'route': '/downloads'};
        return decoded;
      }
    } on FormatException {
      // Legacy route-only payload.
    }
    return <String, dynamic>{'route': payload};
  }

  static String _downloadPayload(int count) => jsonEncode(<String, Object>{'kind': 'downloaded', 'count': count});

  static int? _downloadCount(String? payload) {
    if (payload == 'downloaded') return 0;
    if (payload == null || payload.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic> && decoded['kind'] == 'downloaded') {
        final Object? count = decoded['count'];
        if (count is int && count >= 0) return count;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<void> createDownloadNotification(AppLocalizations l10n) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'downloads',
      l10n.notifChannelDownloads,
      channelDescription: l10n.notifChannelDownloadsDescription,
      importance: Importance.max,
      priority: Priority.high,
      showProgress: true,
      indeterminate: true,
      ongoing: true,
      color: const Color(0xFFE57697),
      playSound: false,
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: l10n.notifDownloadingWallpaper,
      body: "",
      notificationDetails: platformChannelSpecifics,
      payload: "downloadProgress",
    );
  }

  /// One id per logical push. The same push can arrive twice (user topic and device token), and one id makes the
  /// second banner replace the first.
  @visibleForTesting
  static int pushNotificationId(RemoteMessage message) {
    final String tag = message.notification?.android?.tag ?? '';
    final String basis = tag.isNotEmpty
        ? tag
        : '${message.notification?.title}${message.notification?.body}${jsonEncode(message.data)}';
    return basis.hashCode & 0x7fffffff;
  }

  /// Shows a heads-up local notification for a foreground FCM push message.
  Future<void> showPushNotification(RemoteMessage message, {required AppLocalizations localizations}) async {
    final RemoteNotification? notification = message.notification;
    final String? copyKind = message.data['notification_copy_kind']?.toString();
    if (notification == null && copyKind == null) return;
    final Map<String, Object?> copyArgs = _copyArguments(message.data['notification_args']);
    final ({String title, String body}) copy = localizedNotificationCopyData(
      copyKind,
      copyArgs,
      fallbackTitle: notification?.title ?? '',
      fallbackBody: notification?.body ?? '',
      l10n: localizations,
    );
    if (copy.title.trim().isEmpty && copy.body.trim().isEmpty) return;
    final String channelId = (message.data['channel_id']?.toString() ?? '').trim();
    final String resolvedChannelId = channelId.isEmpty ? 'posts' : channelId;
    final String resolvedChannelName = switch (resolvedChannelId) {
      'recommendations' => localizations.notifChannelRecommendations,
      'streak_reminder' => localizations.notifChannelStreaks,
      'moderation' => localizations.notifChannelModeration,
      'followers' => localizations.notifChannelFollowers,
      'wall_of_the_day' => localizations.notifChannelWotd,
      'drops' => localizations.notifChannelDrops,
      'draw' => localizations.notifChannelDraw,
      'gifts' => localizations.notifChannelGifts,
      _ => localizations.notifChannelPosts,
    };
    final String resolvedChannelDescription = switch (resolvedChannelId) {
      'recommendations' => localizations.notifChannelRecommendationsDescription,
      'streak_reminder' => localizations.notifChannelStreaksDescription,
      'moderation' => localizations.notifChannelModerationDescription,
      'followers' => localizations.notifChannelFollowersDescription,
      'wall_of_the_day' => localizations.notifChannelWotdDescription,
      'drops' => localizations.notifChannelDropsDescription,
      'draw' => localizations.notifChannelDrawDescription,
      'gifts' => localizations.notifChannelGiftsDescription,
      _ => localizations.notifChannelPostsDescription,
    };

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      resolvedChannelId,
      resolvedChannelName,
      channelDescription: resolvedChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      tag: message.notification?.android?.tag,
      onlyAlertOnce: true,
    );
    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // iOS refuses show() with UNError 2003 when the user has not allowed notifications.
    final IOSFlutterLocalNotificationsPlugin? iOS = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iOS != null && (await iOS.checkPermissions())?.isEnabled != true) return;

    await flutterLocalNotificationsPlugin.show(
      id: pushNotificationId(message),
      title: copy.title,
      body: copy.body,
      notificationDetails: platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  static Map<String, Object?> _copyArguments(Object? raw) {
    if (raw is! String || raw.isEmpty) return const <String, Object?>{};
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? Map<String, Object?>.from(decoded) : const <String, Object?>{};
    } on FormatException {
      return const <String, Object?>{};
    }
  }

  Future<void> cancelDownloadNotification(AppLocalizations l10n) async {
    await flutterLocalNotificationsPlugin.cancel(id: 0);
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'downloads',
      l10n.notifChannelDownloads,
      channelDescription: l10n.notifChannelDownloadsDescription,
      importance: Importance.min,
      priority: Priority.min,
      color: const Color(0xFFE57697),
      playSound: false,
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    final List<ActiveNotification> activeNotifications =
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.getActiveNotifications() ??
        [];
    final String? previousPayload = activeNotifications.where((n) => n.id == 1).firstOrNull?.payload;
    final int count = (_downloadCount(previousPayload) ?? 0) + 1;
    await flutterLocalNotificationsPlugin.show(
      id: 1,
      title: downloadedTitle(count, l10n),
      body: l10n.notifTapToOpenPrism,
      notificationDetails: platformChannelSpecifics,
      payload: _downloadPayload(count),
    );
  }
}
