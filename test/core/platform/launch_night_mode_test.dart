import 'package:Prism/core/platform/launch_night_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('prism/launch_theme');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('Android receives the in-app theme mode for the next launch splash', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    for (final ThemeMode mode in ThemeMode.values) {
      await syncLaunchNightMode(mode);
    }
    expect(calls.map((call) => '${call.method}:${call.arguments}'), <String>[
      'setNightMode:system',
      'setNightMode:light',
      'setNightMode:dark',
    ]);
  });

  test('iOS sends nothing, its launch screen follows the system appearance', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await syncLaunchNightMode(ThemeMode.light);
    expect(calls, isEmpty);
  });

  test('a missing native handler does not throw', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await expectLater(syncLaunchNightMode(ThemeMode.dark), completes);
  });
}
