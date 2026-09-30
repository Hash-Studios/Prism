import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/router/app_router.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
  AppRouter? router;
  Future<void> Function(Map<String, dynamic>)? onPushTap;
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
        if (response.payload == 'downloaded') {
          router?.push(const DownloadRoute());
        } else {
          final Map<String, dynamic>? payload = _decodePushPayload(response.payload);
          if (payload != null) unawaited(onPushTap?.call(payload));
        }
      },
    );
  }

  /// Title for the download summary notification: one more than the count in [previousTitle].
  @visibleForTesting
  static String downloadedTitle(String? previousTitle) {
    final int count = (int.tryParse(RegExp(r'^\d+').stringMatch(previousTitle ?? '') ?? '') ?? 0) + 1;
    return '$count ${count == 1 ? 'wall' : 'walls'} downloaded.';
  }

  Future<void> fetchNotificationData(BuildContext context) async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails = await flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (!context.mounted) {
      return;
    }
    final String? payload = notificationAppLaunchDetails?.notificationResponse?.payload;
    if (payload == 'downloaded') {
      context.router.push(const DownloadRoute());
    } else {
      final Map<String, dynamic>? pushPayload = _decodePushPayload(payload);
      if (pushPayload != null) await onPushTap?.call(pushPayload);
    }
  }

  static Map<String, dynamic>? _decodePushPayload(String? payload) {
    if (payload == null || payload.isEmpty || payload == 'downloadProgress') return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Older local notifications stored only the route string.
    }
    return <String, dynamic>{'route': payload};
  }

  Future<void> createNotificationChannel(String id, String name, String description, bool playSound) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation == null) {
      return;
    }

    const String channelGroupId = 'notifications';
    const AndroidNotificationChannelGroup androidNotificationChannelGroup = AndroidNotificationChannelGroup(
      channelGroupId,
      'Notifications',
      description: 'All Prism Notifications',
    );
    await androidImplementation.createNotificationChannelGroup(androidNotificationChannelGroup);

    final androidNotificationChannel = AndroidNotificationChannel(
      id,
      name,
      description: description,
      playSound: playSound,
    );
    await androidImplementation.createNotificationChannel(androidNotificationChannel);
  }

  Future<void> createDownloadNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Get notifications for download progress of wallpapers.',
      importance: Importance.max,
      priority: Priority.high,
      showProgress: true,
      indeterminate: true,
      ongoing: true,
      color: Color(0xFFE57697),
      playSound: false,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'Downloading Wallpaper',
      body: "",
      notificationDetails: platformChannelSpecifics,
      payload: "downloadProgress",
    );
  }

  /// Shows a heads-up local notification for a foreground FCM push message.
  Future<void> showPushNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;
    final String channelId = (message.data['channel_id']?.toString() ?? '').trim();
    final String resolvedChannelId = channelId.isEmpty ? 'posts' : channelId;
    final String resolvedChannelName = channelId == 'streak_reminder' ? 'Streak reminders' : 'Posts';
    final String resolvedChannelDescription = channelId == 'streak_reminder'
        ? '8 PM reminder to keep your login streak alive.'
        : 'Get notifications for posts from artists you follow.';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      resolvedChannelId,
      resolvedChannelName,
      channelDescription: resolvedChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> cancelDownloadNotification() async {
    await flutterLocalNotificationsPlugin.cancel(id: 0);
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Get notifications for download progress of wallpapers.',
      importance: Importance.min,
      priority: Priority.min,
      color: Color(0xFFE57697),
      playSound: false,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    final List<ActiveNotification> activeNotifications =
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.getActiveNotifications() ??
        [];
    final String? previousTitle = activeNotifications.where((n) => n.id == 1).firstOrNull?.title;
    await flutterLocalNotificationsPlugin.show(
      id: 1,
      title: downloadedTitle(previousTitle),
      body: "Tap to open Prism.",
      notificationDetails: platformChannelSpecifics,
      payload: "downloaded",
    );
  }
}
