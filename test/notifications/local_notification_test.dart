import 'dart:convert';

import 'package:Prism/notifications/local_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

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

      await notification.fetchNotificationData(tester.element(find.byType(SizedBox)));
      expect(received, <Map<String, dynamic>>[
        <String, dynamic>{'route': 'wall_of_the_day', 'wall_id': 'w1'},
      ]);

      // RestartWidget after logout runs this again with the same launch details.
      await notification.fetchNotificationData(tester.element(find.byType(SizedBox)));
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

      await notification.fetchNotificationData(tester.element(find.byType(SizedBox)));

      expect(received, isEmpty);
    });
  });
}
