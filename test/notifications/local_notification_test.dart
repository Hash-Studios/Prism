import 'dart:convert';

import 'package:Prism/notifications/local_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _notificationChannel = MethodChannel('dexterous.com/flutter/local_notifications');

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

  group('push taps', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() => AndroidFlutterLocalNotificationsPlugin.registerWith());

    tearDown(() {
      messenger.setMockMethodCallHandler(_notificationChannel, null);
    });

    testWidgets('foreground notification payload retains the full push data', (tester) async {
      Map<Object?, Object?>? showArguments;
      messenger.setMockMethodCallHandler(_notificationChannel, (call) async {
        if (call.method == 'show') showArguments = call.arguments as Map<Object?, Object?>;
        return true;
      });

      final notification = LocalNotification();
      await notification.showPushNotification(
        const RemoteMessage(
          data: <String, dynamic>{'route': 'setup', 'url': 'https://prismwalls.com/l/short-id'},
          notification: RemoteNotification(title: 'New setup', body: 'Tap to view'),
        ),
      );

      expect(jsonDecode(showArguments!['payload']! as String), <String, dynamic>{
        'route': 'setup',
        'url': 'https://prismwalls.com/l/short-id',
      });
    });

    testWidgets('tap dispatches legacy plain route and JSON push payload', (tester) async {
      messenger.setMockMethodCallHandler(_notificationChannel, (_) async => true);
      final notification = LocalNotification();
      final received = <Map<String, dynamic>>[];
      notification.onPushTap = (payload) async => received.add(payload);
      await tester.pump();

      Future<void> tap(String payload) async {
        await messenger.handlePlatformMessage(
          _notificationChannel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('didReceiveNotificationResponse', <String, Object?>{
              'notificationId': 1,
              'actionId': null,
              'input': null,
              'payload': payload,
              'notificationResponseType': 0,
            }),
          ),
          (_) {},
        );
        await tester.pump();
      }

      await tap('setup');
      await tap('{"route":"share-setup","url":"https://prismwalls.com/l/short-id"}');
      await tap('downloaded');

      expect(received, <Map<String, dynamic>>[
        <String, dynamic>{'route': 'setup'},
        <String, dynamic>{'route': 'share-setup', 'url': 'https://prismwalls.com/l/short-id'},
      ]);
    });

    testWidgets('cold launch dispatches legacy route and preserves URL fields', (tester) async {
      String? launchPayload = 'setup';
      messenger.setMockMethodCallHandler(_notificationChannel, (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          return <String, Object?>{
            'notificationLaunchedApp': true,
            'notificationResponse': <String, Object?>{
              'notificationId': 1,
              'actionId': null,
              'input': null,
              'payload': launchPayload,
              'notificationResponseType': 0,
            },
          };
        }
        return true;
      });
      final notification = LocalNotification();
      final received = <Map<String, dynamic>>[];
      notification.onPushTap = (payload) async => received.add(payload);
      Future<void>? launchFuture;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              launchFuture ??= notification.fetchNotificationData(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await launchFuture;
      expect(received, <Map<String, dynamic>>[
        <String, dynamic>{'route': 'setup'},
      ]);

      launchPayload = '{"route":"share-setup","url":"https://prismwalls.com/l/cold-start"}';
      await notification.fetchNotificationData(tester.element(find.byType(SizedBox)));
      expect(received, <Map<String, dynamic>>[
        <String, dynamic>{'route': 'setup'},
        <String, dynamic>{'route': 'share-setup', 'url': 'https://prismwalls.com/l/cold-start'},
      ]);
    });
  });
}
