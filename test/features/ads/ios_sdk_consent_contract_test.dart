// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Analytics defaults deny advertising data and delay App Measurement', () {
    final String infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(_plistBoolean(infoPlist, 'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE'), isFalse);
    expect(_plistBoolean(infoPlist, 'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA'), isFalse);
    expect(_plistBoolean(infoPlist, 'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS'), isFalse);
    expect(_plistBoolean(infoPlist, 'GADDelayAppMeasurementInit'), isTrue);
  });

  test('real Analytics consent adapter waits for Firebase and sends final iOS decisions only', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();

    const String channel =
        'dev.flutter.pigeon.firebase_analytics_platform_interface.FirebaseAnalyticsHostApi.setConsent';
    const StandardMessageCodec codec = StandardMessageCodec();
    final List<Map<Object?, Object?>> calls = <Map<Object?, Object?>>[];
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(channel, (ByteData? data) async {
      final List<Object?> message = codec.decodeMessage(data)! as List<Object?>;
      calls.add(message.single! as Map<Object?, Object?>);
      return codec.encodeMessage(<Object?>[null]);
    });
    addTearDown(() => messenger.setMockMessageHandler(channel, null));

    final Completer<bool> firebaseReady = Completer<bool>();
    FirebaseInit.setFuture(firebaseReady.future);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final AdConsent denied = AdConsent(requestTracking: () async => false);
    expect(await denied.requestTracking(), isTrue);
    await pumpEventQueue();
    expect(calls, isEmpty, reason: 'The adapter must not touch Firebase before its startup future completes.');

    firebaseReady.complete(true);
    await FirebaseInit.readyFuture;
    await pumpEventQueue();
    expect(calls, <Map<Object?, Object?>>[
      <String, bool>{
        'adStorageConsentGranted': false,
        'adUserDataConsentGranted': false,
        'adPersonalizationSignalsConsentGranted': false,
      },
    ]);

    final AdConsent granted = AdConsent(requestTracking: () async => true);
    expect(await granted.requestTracking(), isTrue);
    await pumpEventQueue();
    expect(calls.last, <String, bool>{
      'adStorageConsentGranted': true,
      'adUserDataConsentGranted': true,
      'adPersonalizationSignalsConsentGranted': true,
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final AdConsent android = AdConsent(requestTracking: () async => true);
    expect(await android.requestTracking(), isTrue);
    await pumpEventQueue();
    expect(calls, hasLength(2), reason: 'Android must not use the iOS Analytics identifier-consent adapter.');
  });
}

bool _plistBoolean(String plist, String key) {
  final RegExp expression = RegExp('<key>$key</key>\\s*<(true|false)/>');
  final RegExpMatch? match = expression.firstMatch(plist);
  expect(match, isNotNull, reason: 'Info.plist must define $key as a boolean.');
  return match!.group(1) == 'true';
}
