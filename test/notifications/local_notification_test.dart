// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:Prism/notifications/local_notification.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
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

  group('pushNotificationId', () {
    RemoteMessage message({String? tag, String title = 'T', String body = 'B', Map<String, dynamic>? data}) =>
        RemoteMessage(
          data: data ?? const <String, dynamic>{},
          notification: RemoteNotification(
            title: title,
            body: body,
            android: tag == null ? null : AndroidNotification(tag: tag),
          ),
        );

    test('the same tag gives the same id, so the second banner replaces the first', () {
      expect(
        LocalNotification.pushNotificationId(message(tag: 'wall_w1')),
        LocalNotification.pushNotificationId(message(tag: 'wall_w1', title: 'Other')),
      );
    });

    test('different tags give different ids', () {
      expect(
        LocalNotification.pushNotificationId(message(tag: 'wall_w1')),
        isNot(LocalNotification.pushNotificationId(message(tag: 'wall_w2'))),
      );
    });

    test('without a tag the id comes from title, body and data', () {
      final RemoteMessage a = message(data: const <String, dynamic>{'route': 'wall', 'wall_id': 'w1'});
      final RemoteMessage same = message(data: const <String, dynamic>{'route': 'wall', 'wall_id': 'w1'});
      final RemoteMessage other = message(data: const <String, dynamic>{'route': 'wall', 'wall_id': 'w2'});

      expect(LocalNotification.pushNotificationId(a), LocalNotification.pushNotificationId(same));
      expect(LocalNotification.pushNotificationId(a), isNot(LocalNotification.pushNotificationId(other)));
      expect(LocalNotification.pushNotificationId(a), greaterThanOrEqualTo(0));
      expect(LocalNotification.pushNotificationId(a), lessThan(1 << 31));
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

    testWidgets('a tagged push shows with its tag, a stable id and no repeat alert', (tester) async {
      final shown = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'show') shown.add(call.arguments as Map<Object?, Object?>);
        return true;
      });
      const RemoteMessage push = RemoteMessage(
        notification: RemoteNotification(
          title: 'New follower',
          body: 'Ana follows you',
          android: AndroidNotification(tag: 'follow_ana'),
        ),
      );

      await LocalNotification().showPushNotification(push);
      await LocalNotification().showPushNotification(push);

      expect(shown, hasLength(2));
      expect(shown[0]['id'], shown[1]['id']);
      final platformSpecifics = shown[0]['platformSpecifics']! as Map<Object?, Object?>;
      expect(platformSpecifics['tag'], 'follow_ana');
      expect(platformSpecifics['onlyAlertOnce'], isTrue);
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
        'downloaded',
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
        <String, dynamic>{'route': '/downloads'},
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

    testWidgets('a cold downloads launch uses the shared callback once and waits for it', (tester) async {
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          return <String, Object?>{'notificationLaunchedApp': true, 'notificationResponse': _response('downloaded')};
        }
        return true;
      });
      final notification = LocalNotification();
      final callback = Completer<void>();
      final received = <Map<String, dynamic>>[];
      notification.onPushTap = (data) {
        received.add(data);
        return callback.future;
      };
      var completed = false;
      final Future<void> fetch = notification.fetchNotificationData().whenComplete(() => completed = true);
      await tester.pump();
      expect(completed, isFalse);
      expect(received, <Map<String, dynamic>>[
        <String, dynamic>{'route': '/downloads'},
      ]);
      callback.complete();
      await tester.pump();
      await fetch;
      expect(completed, isTrue);
      await notification.fetchNotificationData();
      expect(received, hasLength(1));
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
