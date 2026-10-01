// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/features/quick_tiles/views/quick_tile_settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw PlatformException(code: 'write_failed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final haptics = <Object?>[];
  final messages = <String>[];
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() {
    haptics.clear();
    messages.clear();
    PrismHaptics.enabled = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    messenger.setMockMethodCallHandler(toastChannel, (call) async {
      messages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    debugDefaultTargetPlatformOverride = null;
    PrismHaptics.enabled = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('mapping a launch setup link keeps the notice but has no user-action haptic', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final route = await const DeepLinkNavigation().mapUriToRoute(Uri.parse('prism://setup/minimal-desk'));
    await Future<void>.delayed(Duration.zero);

    expect(route, isA<HomeTabRoute>());
    expect(messages, <String>['Home screen setups are no longer available.']);
    expect(haptics, isEmpty);
  });

  testWidgets('failed quick tile save plays error, not success', (tester) async {
    SharedPreferencesStorePlatform.instance = _FailingPreferences();
    await tester.pumpWidget(const MaterialApp(home: QuickTileSettingsScreen()));
    await tester.pumpAndSettle();
    expect(haptics, isEmpty);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(messages, <String>['Failed to save settings']);
    expect(haptics, <String>['HapticFeedbackType.errorNotification']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('successful quick tile save plays success once', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuickTileSettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(messages, <String>['Quick tile settings saved!']);
    expect(haptics, <String>['HapticFeedbackType.successNotification']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
