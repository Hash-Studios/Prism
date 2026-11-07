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

  testWidgets('a temporarily missing native handler retries the requested mode', (tester) async {
    String? persistedMode;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (calls.length == 1) throw MissingPluginException();
      persistedMode = call.arguments as String;
      return null;
    });

    final Future<void> sync = syncLaunchNightMode(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await sync;

    expect(persistedMode, 'dark');
    expect(calls.map((call) => call.arguments), <String>['dark', 'dark']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an older missing-handler retry cannot overwrite a newer theme', (tester) async {
    String? persistedMode;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (calls.length == 1) throw MissingPluginException();
      persistedMode = call.arguments as String;
      return null;
    });

    final Future<void> darkSync = syncLaunchNightMode(ThemeMode.dark);
    await tester.pump();
    await syncLaunchNightMode(ThemeMode.light);
    await tester.pump(const Duration(seconds: 1));
    await darkSync;

    expect(persistedMode, 'light');
    expect(calls.map((call) => call.arguments), <String>['dark', 'light']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a permanently missing handler stops retrying', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return Future<Object?>.error(MissingPluginException());
    });

    final Future<void> sync = syncLaunchNightMode(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await sync;
    expect(calls.map((call) => call.arguments), <String>['dark', 'dark']);
    await tester.pump(const Duration(seconds: 10));
    expect(calls, hasLength(2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('a native error does not block the next theme change', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    String? persistedMode;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (calls.length == 1) throw PlatformException(code: 'UNAVAILABLE');
      persistedMode = call.arguments as String;
      return null;
    });

    await syncLaunchNightMode(ThemeMode.dark);
    await syncLaunchNightMode(ThemeMode.system);

    expect(persistedMode, 'system');
    expect(calls.map((call) => call.arguments), <String>['dark', 'system']);
  });

  testWidgets('native reattachment replays the latest mode after bounded retries end', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return Future<Object?>.error(MissingPluginException());
    });
    final Future<void> darkSync = syncLaunchNightMode(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await darkSync;
    final Future<void> systemSync = syncLaunchNightMode(ThemeMode.system);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await systemSync;

    String? persistedMode;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      persistedMode = call.arguments as String;
      return null;
    });
    ByteData? response;
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('ready')),
      (data) => response = data,
    );
    await tester.pump();

    expect(persistedMode, 'system');
    expect(const StandardMethodCodec().decodeEnvelope(response!), isNull);
    expect(calls.last.arguments, 'system');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
