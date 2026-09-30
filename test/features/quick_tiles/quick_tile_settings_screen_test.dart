import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/quick_tiles/views/quick_tile_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (call) async => true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: QuickTileSettingsScreen()));
  }

  testWidgets('shows a skeleton while loading, then one card per tile', (tester) async {
    await pumpScreen(tester);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('Quick tiles'), findsOneWidget);
    expect(find.text('Shuffle wallpaper tile'), findsOneWidget);
    expect(find.text('Wall of the Day tile'), findsOneWidget);
    expect(find.text('Random favourite tile'), findsOneWidget);
    expect(find.text('How to add a tile'), findsOneWidget);
    expect(find.text('Apply to'), findsNWidgets(3));
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('saving writes the chosen target', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lock').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PersistenceKeys.quickTileWotdTarget), isNotNull);
    expect(prefs.getString(PersistenceKeys.quickTileCategoryTarget), isNotNull);
  });
}
