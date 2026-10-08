import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/quick_tiles/views/quick_tile_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('prism/quick_settings');
  late FakeAppAnalytics analytics;
  final List<MethodCall> calls = <MethodCall>[];

  void fakeChannel({required int sdkInt, int addResult = 2}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'sdkInt' => sdkInt,
        'requestAddTile' => addResult,
        _ => null,
      };
    });
  }

  setUp(() async {
    calls.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: const QuickTileSettingsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows one add button per tile on Android 13 and up', (tester) async {
    fakeChannel(sdkInt: 33);
    await pumpScreen(tester);

    expect(find.text('Add to Quick Settings'), findsNWidgets(3));
  });

  testWidgets('hides the add buttons below Android 13', (tester) async {
    fakeChannel(sdkInt: 32);
    await pumpScreen(tester);

    expect(find.text('Add to Quick Settings'), findsNothing);
  });

  testWidgets('tapping a button asks the system, shows a snackbar and tracks the result', (tester) async {
    fakeChannel(sdkInt: 34);
    await pumpScreen(tester);

    await tester.tap(find.text('Add to Quick Settings').at(1));
    await tester.pumpAndSettle();

    expect(calls.where((c) => c.method == 'requestAddTile').single.arguments, 'wotd');
    expect(find.text('Tile added to Quick Settings.'), findsOneWidget);
    final QuickTileAddRequestedEvent event = analytics.events.whereType<QuickTileAddRequestedEvent>().single;
    expect(event.tile, 'wotd');
    expect(event.result, 'added');
  });

  testWidgets('shows a calm message when the system declines', (tester) async {
    fakeChannel(sdkInt: 34, addResult: 0);
    await pumpScreen(tester);

    await tester.tap(find.text('Add to Quick Settings').first);
    await tester.pumpAndSettle();

    expect(find.text('Tile not added. You can add it any time.'), findsOneWidget);
    expect(analytics.events.whereType<QuickTileAddRequestedEvent>().single.result, 'notAdded');
  });
}
