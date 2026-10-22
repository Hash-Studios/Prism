import 'dart:async';

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
  Future<List<String>> Function()? readKeys;
  Future<void> Function()? beforeWrite;
  Future<void> Function()? beforeDelete;

  @override
  Future<List<String>> keys() async {
    if (readKeys != null) return readKeys!();
    if (failRead) throw StateError('storage read failed');
    return await super.keys();
  }

  @override
  Future<void> set(String key, Object? value) async {
    await beforeWrite?.call();
    if (failWrite) throw StateError('storage write failed');
    await super.set(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await beforeDelete?.call();
    await super.delete(key);
  }

  @override
  Future<void> clearAll() async {
    await beforeDelete?.call();
    await super.clearAll();
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

  for (final (Object?, String, Object?) edit in <(Object?, String, Object?)>[
    (true, 'false', false),
    (12, '23', 23),
    (1.5, '2.5', 2.5),
    (<Object?>[1, true], '[2,false]', <Object?>[2, false]),
    (<String, Object?>{'a': 1}, '{"a":2}', <String, Object?>{'a': 2}),
    ('true', '123', '123'),
    (null, 'null', null),
  ]) {
    testWidgets('editing ${edit.$1.runtimeType} preserves the stored type', (tester) async {
      store.data['preference'] = edit.$1;
      await pump(tester);
      await tester.tap(find.text('preference'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, edit.$2);
      await tester.tap(find.widgetWithText(PrismButton, 'Save'));
      await tester.pumpAndSettle();
      expect(store.data['preference'], edit.$3);
      expect(find.text('Edit value'), findsNothing);
    });
  }

  testWidgets('an invalid integer keeps the editor open without writing', (tester) async {
    store.data['preference'] = 12;
    await pump(tester);
    await tester.tap(find.text('preference'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'not an integer');
    await tester.tap(find.widgetWithText(PrismButton, 'Save'));
    await tester.pumpAndSettle();
    expect(store.data['preference'], 12);
    expect(find.text('Edit value'), findsOneWidget);
  });

  for (final Object? original in <Object?>[
    true,
    12,
    1.5,
    <Object?>[1, true],
    <String, Object?>{'a': 1},
    'true',
    null,
  ]) {
    testWidgets('saving ${original.runtimeType} unchanged round trips its value', (tester) async {
      store.data['preference'] = original;
      await pump(tester);
      await tester.tap(find.text('preference'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrismButton, 'Save'));
      await tester.pumpAndSettle();
      expect(store.data['preference'], original);
      expect(find.text('Edit value'), findsNothing);
    });
  }

  for (final bool clearAll in <bool>[false, true]) {
    testWidgets('${clearAll ? 'clear' : 'delete'} completing after disposal does not refresh the page', (tester) async {
      await pump(tester);
      final gate = Completer<void>();
      store.beforeDelete = () => gate.future;
      await tester.tap(find.byTooltip(clearAll ? 'Clear all' : 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(clearAll ? 'Clear all' : 'Delete key').last);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pump();
      expect(store.data, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final bool fail in <bool>[false, true]) {
    testWidgets('a key read completing after disposal ignores ${fail ? 'failure' : 'success'}', (tester) async {
      final gate = Completer<List<String>>();
      store.readKeys = () => gate.future;
      await pump(tester);
      await tester.pumpWidget(const SizedBox());
      if (fail) {
        gate.completeError(StateError('offline'));
      } else {
        gate.complete(<String>['preference']);
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a late refresh cannot replace the newest key list', (tester) async {
    await pump(tester);
    final old = Completer<List<String>>();
    store.readKeys = () => old.future;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    store.data['newest'] = 'value';
    store.readKeys = () async => <String>['newest'];
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    old.complete(<String>['preference']);
    await tester.pump();
    expect(find.text('newest'), findsOneWidget);
    expect(find.text('preference'), findsNothing);
  });

  testWidgets('a save completing after the page is gone does not refresh it', (tester) async {
    await pump(tester);
    await tester.tap(find.text('preference'));
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    store.beforeWrite = () => gate.future;
    await tester.tap(find.widgetWithText(PrismButton, 'Save'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
