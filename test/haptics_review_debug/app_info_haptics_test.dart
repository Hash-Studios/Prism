import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/debug_panel/views/pages/app_info_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const androidChannel = MethodChannel('prism/haptics');
  final platformHaptics = <Object?>[];
  final androidHaptics = <MethodCall>[];
  final copiedValues = <String>[];

  setUp(() {
    platformHaptics.clear();
    androidHaptics.clear();
    copiedValues.clear();
    PrismHaptics.enabled = true;
    PackageInfo.setMockInitialValues(
      appName: 'Prism test',
      packageName: 'com.hash.prism.test',
      version: '1.2.3',
      buildNumber: '123',
      buildSignature: '',
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') platformHaptics.add(call.arguments);
      if (call.method == 'Clipboard.setData') {
        copiedValues.add((call.arguments as Map<Object?, Object?>)['text']! as String);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(androidChannel, (call) async {
      androidHaptics.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(androidChannel, null);
    PrismHaptics.enabled = true;
  });

  for (final platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('${platform.name} info row copies with one impact, and still copies silently when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppInfoPage())));
      await tester.pumpAndSettle();
      expect(platformHaptics, isEmpty);
      expect(androidHaptics, isEmpty);

      await tester.longPress(find.text('Version'));
      await tester.pump();

      expect(copiedValues, <String>['1.2.3']);
      if (platform == TargetPlatform.iOS) {
        expect(platformHaptics, <String>['HapticFeedbackType.mediumImpact']);
        expect(androidHaptics, isEmpty);
      } else {
        expect(platformHaptics, isEmpty);
        expect(androidHaptics.map((call) => '${call.method}:${call.arguments}'), <String>['play:impact']);
      }

      platformHaptics.clear();
      androidHaptics.clear();
      PrismHaptics.enabled = false;
      await tester.longPress(find.text('Version'));
      await tester.pump();

      expect(copiedValues, <String>['1.2.3', '1.2.3']);
      expect(platformHaptics, isEmpty);
      expect(androidHaptics, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(platform));
  }
}
