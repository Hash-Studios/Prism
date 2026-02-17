import 'package:Prism/core/router/route_names.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotification {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  LocalNotification() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
  }

  Future<void> fetchNotificationData(BuildContext context) async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (!context.mounted) {
      return;
    }
    if (notificationAppLaunchDetails?.notificationResponse?.payload == "downloaded") {
      context.pushNamedRoute(downloadRoute);
    }
  }

  Future<void> createNotificationChannel(String id, String name, String description, bool playSound) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation == null) {
      return;
    }

    const String channelGroupId = 'notifications';
    const AndroidNotificationChannelGroup androidNotificationChannelGroup =
        AndroidNotificationChannelGroup(channelGroupId, 'Notifications', description: 'All Prism Notifications');
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
    final List<ActiveNotification> activeNotifications = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.getActiveNotifications() ??
        [];
    await flutterLocalNotificationsPlugin.show(
      id: 1,
      title: (activeNotifications.length + 1) == 1
          ? '1 wall downloaded.'
          : '${int.parse(activeNotifications[0].title![0]) + 1} walls downloaded.',
      body: "Tap to open Prism.",
      notificationDetails: platformChannelSpecifics,
      payload: "downloaded",
    );
  }
}
