import 'package:Prism/routes/routing_constants.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class LocalNotification {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  LocalNotification() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> fetchNotificationData(BuildContext context) async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails!.payload == "downloaded") {
      Navigator.pushNamed(context, downloadRoute);
    }
  }

  Future<void> createNotificationChannel(
      String id, String name, String description, bool playSound) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const String channelGroupId = 'notifications';
    const AndroidNotificationChannelGroup androidNotificationChannelGroup =
        AndroidNotificationChannelGroup(channelGroupId, 'Notifications',
            description: 'All Prism Notifications');
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannelGroup(androidNotificationChannelGroup);

    final androidNotificationChannel = AndroidNotificationChannel(
      id,
      name,
      description,
      playSound: playSound,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);
  }

  Future<void> createDownloadNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'downloads',
      'Downloads',
      'Get notifications for download progress of wallpapers.',
      importance: Importance.max,
      priority: Priority.high,
      showProgress: true,
      indeterminate: true,
      ongoing: true,
      color: Color(0xFFE57697),
      playSound: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Downloading Wallpaper',
      "",
      platformChannelSpecifics,
      payload: "downloadProgress",
    );
  }

  Future<void> cancelDownloadNotification() async {
    await flutterLocalNotificationsPlugin.cancel(0);
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'downloads',
      'Downloads',
      'Get notifications for download progress of wallpapers.',
      importance: Importance.min,
      priority: Priority.min,
      color: Color(0xFFE57697),
      playSound: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    final List<ActiveNotification> activeNotifications =
        await flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.getActiveNotifications() ??
            [];
    await flutterLocalNotificationsPlugin.show(
      1,
      (activeNotifications.length + 1) == 1
          ? '1 wall downloaded.'
          : '${int.parse(activeNotifications[0].title![0]) + 1} walls downloaded.',
      "Tap to open Prism.",
      platformChannelSpecifics,
      payload: "downloaded",
    );
  }
}
