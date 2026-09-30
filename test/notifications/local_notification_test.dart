// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/notifications/local_notification.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stub_app_router.dart';

const MethodChannel _channel = MethodChannel('dexterous.com/flutter/local_notifications');

Map<String, Object?> _response(String payload) => <String, Object?>{
  'notificationId': 1,
  'actionId': null,
  'input': null,
  'payload': payload,
  'notificationResponseType': 0,
};

void main() {
  test('startup init does not ask for iOS notification permission', () {
    const settings = LocalNotification.darwinSettings;

    expect(settings.requestAlertPermission, isFalse);
    expect(settings.requestSoundPermission, isFalse);
    expect(settings.requestBadgePermission, isFalse);
  });

  group('downloadedTitle', () {
    test('starts at one wall', () {
      expect(LocalNotification.downloadedTitle(null), '1 wall downloaded.');
      expect(LocalNotification.downloadedTitle('Downloading Wallpaper'), '1 wall downloaded.');
    });

    test('counts up from the previous title', () {
      expect(LocalNotification.downloadedTitle('1 wall downloaded.'), '2 walls downloaded.');
      expect(LocalNotification.downloadedTitle('9 walls downloaded.'), '10 walls downloaded.');
      expect(LocalNotification.downloadedTitle('12 walls downloaded.'), '13 walls downloaded.');
    });
  });

  group('foreground push notifications', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(AndroidFlutterLocalNotificationsPlugin.registerWith);
    tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

    testWidgets('the payload keeps the full push data, not only the route', (tester) async {
      Map<Object?, Object?>? shown;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'show') shown = call.arguments as Map<Object?, Object?>;
        return true;
      });

      await LocalNotification().showPushNotification(
        const RemoteMessage(
          data: <String, dynamic>{
            'route': 'wall_of_the_day',
            'wall_id': 'w1',
            'url': 'https://prismwalls.com/share?id=a',
          },
          notification: RemoteNotification(title: 'WOTD', body: 'New wall'),
        ),
      );

      expect(jsonDecode(shown!['payload']! as String), <String, dynamic>{
        'route': 'wall_of_the_day',
        'wall_id': 'w1',
        'url': 'https://prismwalls.com/share?id=a',
      });
    });

    testWidgets('a tap routes the push data, and a legacy route-only payload still works', (tester) async {
      messenger.setMockMethodCallHandler(_channel, (_) async => true);
      final notification = LocalNotification();
      final received = <Map<String, dynamic>>[];
      notification.onPushTap = (data) async => received.add(data);
      await tester.pump();

      for (final payload in <String>[
        '{"route":"follower","url":"https://prismwalls.com/user/bob"}',
        'notifications',
        'downloadProgress',
      ]) {
        await messenger.handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('didReceiveNotificationResponse', _response(payload)),
          ),
          (_) {},
        );
        await tester.pump();
      }

      expect(received, <Map<String, dynamic>>[
        <String, dynamic>{'route': 'follower', 'url': 'https://prismwalls.com/user/bob'},
        <String, dynamic>{'route': 'notifications'},
      ]);
    });

    testWidgets('a cold launch from a push notification routes its data once', (tester) async {
      const String payload = '{"route":"wall_of_the_day","wall_id":"w1"}';
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          return <String, Object?>{'notificationLaunchedApp': true, 'notificationResponse': _response(payload)};
        }
        return true;
      });
      final notification = LocalNotification();
      final received = <Map<String, dynamic>>[];
      notification.onPushTap = (data) async => received.add(data);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      await notification.fetchNotificationData();
      expect(received, <Map<String, dynamic>>[
        <String, dynamic>{'route': 'wall_of_the_day', 'wall_id': 'w1'},
      ]);

      // RestartWidget after logout runs this again with the same launch details.
      await notification.fetchNotificationData();
      expect(received, hasLength(1));
    });

    testWidgets('launch details are ignored when a notification did not launch the app', (tester) async {
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          return <String, Object?>{
            'notificationLaunchedApp': false,
            'notificationResponse': _response('{"route":"wall_of_the_day","wall_id":"w1"}'),
          };
        }
        return true;
      });
      final notification = LocalNotification();
      final received = <Map<String, dynamic>>[];
      notification.onPushTap = (data) async => received.add(data);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      await notification.fetchNotificationData();

      expect(received, isEmpty);
    });

    testWidgets('a cold launch from the downloads notification opens Downloads after the splash, once', (tester) async {
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          return <String, Object?>{'notificationLaunchedApp': true, 'notificationResponse': _response('downloaded')};
        }
        return true;
      });
      final router = StubAppRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
      await tester.pumpAndSettle();
      final notification = LocalNotification()..router = router;

      unawaited(notification.fetchNotificationData());
      await tester.pump(const Duration(milliseconds: 300));
      expect(router.topRoute.name, SplashWidgetRoute.name);

      unawaited(router.replaceAll([const DashboardRoute()]));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(router.topRoute.name, DownloadRoute.name);

      // RestartWidget re-creates the app state, which calls this again with the same launch details.
      unawaited(router.replaceAll([const DashboardRoute()]));
      await notification.fetchNotificationData();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(router.topRoute.name, DashboardRoute.name);
    });

    testWidgets('push messages reach only the latest app state, once', (tester) async {
      var shown = 0;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'show') shown++;
        return true;
      });
      final notification = LocalNotification();
      final firstTaps = <Map<String, dynamic>>[];
      final taps = <Map<String, dynamic>>[];
      var foregroundPushes = 0;
      notification
        ..onPushTap = ((data) async => firstTaps.add(data))
        ..onForegroundPush = (() => foregroundPushes += 100)
        ..listenForPushMessages();

      // RestartWidget: the new app state sets its callbacks and listens again.
      notification
        ..onPushTap = ((data) async => taps.add(data))
        ..onForegroundPush = (() => foregroundPushes++)
        ..listenForPushMessages();

      FirebaseMessagingPlatform.onMessageOpenedApp.add(const RemoteMessage(data: <String, dynamic>{'route': 'wall'}));
      FirebaseMessagingPlatform.onMessage.add(
        const RemoteMessage(
          notification: RemoteNotification(title: 'New wall', body: 'Tap to see it'),
        ),
      );
      await tester.pumpAndSettle();

      expect(firstTaps, isEmpty);
      expect(taps, <Map<String, dynamic>>[
        <String, dynamic>{'route': 'wall'},
      ]);
      expect(foregroundPushes, 1);
      expect(shown, 1);
    });
  });
}
