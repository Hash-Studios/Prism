import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel hapticsChannel = MethodChannel('prism/haptics');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> haptics = <String>[];

  setUp(() {
    PrismHaptics.enabled = true;
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      hapticsChannel,
      (MethodCall call) async => haptics.add(call.arguments! as String),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  testWidgets('quota-blocked upload emits only its error outcome haptic', (tester) async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    app_state.prismUser = app_constants.createGuestPrismUser();
    for (int i = 0; i < UploadQuota.freeUploadsPerWeek; i++) {
      await UploadQuota.incrementWeeklyUploads();
    }

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UploadBottomPanel())));
    await tester.tap(find.text('Wallpapers'));
    await tester.pumpAndSettle();

    expect(haptics, <String>['error']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
