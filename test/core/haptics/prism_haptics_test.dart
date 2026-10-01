import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final List<MethodCall> platformCalls = <MethodCall>[];
  final List<MethodCall> androidCalls = <MethodCall>[];

  setUp(() {
    platformCalls.clear();
    androidCalls.clear();
    PrismHaptics.enabled = true;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), (call) async {
      androidCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    PrismHaptics.enabled = true;
  });

  test('iOS maps each type to a UIKit feedback generator, never the long vibrate', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    PrismHaptics.selection();
    PrismHaptics.tap();
    PrismHaptics.impact();
    PrismHaptics.success();
    PrismHaptics.warning();
    PrismHaptics.error();
    await Future<void>.delayed(Duration.zero);

    expect(platformCalls.map((c) => c.arguments), <String>[
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.successNotification',
      'HapticFeedbackType.warningNotification',
      'HapticFeedbackType.errorNotification',
    ]);
    expect(androidCalls, isEmpty);
  });

  test('Android sends the type to the native channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    PrismHaptics.tap();
    PrismHaptics.success();
    await Future<void>.delayed(Duration.zero);

    expect(androidCalls.map((c) => '${c.method}:${c.arguments}'), <String>['play:tap', 'play:success']);
    expect(platformCalls, isEmpty);
  });

  test('disabled plays nothing on either platform', () async {
    PrismHaptics.enabled = false;
    for (final platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = platform;
      PrismHaptics.tap();
      PrismHaptics.error();
    }
    await Future<void>.delayed(Duration.zero);

    expect(platformCalls, isEmpty);
    expect(androidCalls, isEmpty);
  });

  test('a channel failure does not throw', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), (call) {
      throw PlatformException(code: 'no_vibrator');
    });
    PrismHaptics.impact();
    await Future<void>.delayed(Duration.zero);
  });
}
