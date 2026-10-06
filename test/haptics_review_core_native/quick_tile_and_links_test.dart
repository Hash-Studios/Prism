// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/features/quick_tiles/views/quick_tile_settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../support/in_memory_local_store.dart';

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw PlatformException(code: 'write_failed');
}

class _RejectedPreferences extends InMemorySharedPreferencesStore {
  _RejectedPreferences() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final haptics = <Object?>[];
  final messages = <String>[];
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
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

  tearDown(() async {
    await getIt.reset();
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
    await tester.tap(find.text('Lock').first);
    await tester.pumpAndSettle();

    expect(messages, <String>['Failed to save settings']);
    expect(haptics, <String>['HapticFeedbackType.errorNotification']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('quick tile changes save on their own and stay quiet', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuickTileSettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    await tester.tap(find.text('Lock').first);
    await tester.pumpAndSettle();

    expect(messages, isEmpty);
    expect((await SharedPreferences.getInstance()).getString('quick_tile.category.target'), 'lock');
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('rejected quick tile writes report failure without a success haptic', (tester) async {
    SharedPreferencesStorePlatform.instance = _RejectedPreferences();
    await tester.pumpWidget(const MaterialApp(home: QuickTileSettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock').first);
    await tester.pumpAndSettle();

    expect(messages, <String>['Failed to save settings']);
    expect(haptics, <String>['HapticFeedbackType.errorNotification']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
