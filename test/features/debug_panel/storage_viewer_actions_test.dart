import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/debug_panel/views/pages/storage_viewer_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _FailingStore extends InMemoryLocalStore {
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<List<String>> keys() async {
    if (failRead) throw StateError('storage read failed');
    return await super.keys();
  }

  @override
  Future<void> set(String key, Object? value) async {
    if (failWrite) throw StateError('storage write failed');
    await super.set(key, value);
  }
}

void main() {
  late _FailingStore store;
  late List<String> copied;
  setUp(() {
    store = _FailingStore()..data['preference'] = 'original';
    copied = [];
    PersistenceRuntime.store = store;
    getIt.registerSingleton<LocalStore>(store);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      },
    );
  });
  tearDown(() async {
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: StorageViewerPage()),
      ),
    );
    await tester.pump();
  }

  testWidgets('read failure offers retry and clear all requires confirmation', (tester) async {
    store.failRead = true;
    await pump(tester);
    expect(find.text('Try again'), findsOneWidget);
    store.failRead = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('preference'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy value'));
    await tester.pump();
    expect(copied.single, 'original');
    await tester.tap(find.byTooltip('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.data, containsPair('preference', 'original'));
    await tester.tap(find.byTooltip('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.data, isEmpty);
    expect(find.text('No keys found'), findsOneWidget);
  });

  testWidgets('failed save preserves the value and sheet, allowing retry', (tester) async {
    await pump(tester);
    await tester.tap(find.text('preference'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrismButton, 'Copy'));
    await tester.pump();
    expect(copied.single, 'preference\noriginal');
    await tester.enterText(find.widgetWithText(TextField, 'original'), 'updated');
    store.failWrite = true;
    await tester.tap(find.widgetWithText(PrismButton, 'Save'));
    await tester.pumpAndSettle();
    expect(store.data['preference'], 'original');
    expect(find.text('Edit value'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Save')).loading, isFalse);
    store.failWrite = false;
    await tester.tap(find.widgetWithText(PrismButton, 'Save'));
    await tester.pumpAndSettle();
    expect(store.data['preference'], 'updated');
    expect(find.text('Edit value'), findsNothing);
  });
}
