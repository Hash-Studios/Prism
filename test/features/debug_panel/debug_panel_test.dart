import 'package:Prism/core/debug/debug_flags.dart';
import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/debug/log_toast_overlay.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/debug_panel/views/pages/app_info_page.dart';
import 'package:Prism/features/debug_panel/views/pages/debug_panel_page.dart';
import 'package:Prism/features/debug_panel/views/pages/storage_viewer_page.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/in_memory_local_store.dart';

AppLogRecord _record(int n, AppLogLevel level, String message, {String? tag, Object? error}) => AppLogRecord(
  sequence: n,
  timestamp: DateTime(2026, 1, 2, 3, 4, 5, n * 10),
  level: level,
  message: message,
  tag: tag,
  error: error,
);

Widget _app(Widget home) => MaterialApp(
  builder: (context, child) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    InMemoryLogSink.instance.clear();
    DebugFlags.instance.reset();
  });

  tearDown(() => DebugFlags.instance.reset());

  group('debug panel shell', () {
    testWidgets('has a Debug title, no admin badge and five tabs', (tester) async {
      await tester.pumpWidget(_app(const DebugPanelPage()));
      await tester.pump();

      expect(find.text('Debug'), findsOneWidget);
      expect(find.text('ADMIN'), findsNothing);
      for (final String tab in <String>['Logs', 'Tools', 'Storage', 'App info', 'Mascot']) {
        expect(find.text(tab), findsOneWidget);
      }
    });

    testWidgets('the Mascot tab names the use case of each mood', (tester) async {
      await tester.pumpWidget(_app(const DebugPanelPage()));
      await tester.tap(find.text('Mascot'));
      await tester.pumpAndSettle();

      expect(find.text('Still poses'), findsOneWidget);
      expect(find.text('calm'), findsOneWidget);
      expect(find.text('Empty list'), findsOneWidget);
    });
  });

  group('logs tab', () {
    testWidgets('shows Glint when there are no logs', (tester) async {
      await tester.pumpWidget(_app(const DebugPanelPage()));
      await tester.pump();

      expect(find.byType(GlintState), findsOneWidget);
      expect(find.text('No logs'), findsOneWidget);
      expect(find.text('0 entries'), findsOneWidget);
    });

    testWidgets('lists log lines, filters by level chip and by search', (tester) async {
      InMemoryLogSink.instance
        ..write(_record(1, AppLogLevel.info, 'Session started', tag: 'Session'))
        ..write(_record(2, AppLogLevel.error, 'Upload failed', tag: 'Upload', error: 'boom'));
      await tester.pumpWidget(_app(const DebugPanelPage()));
      await tester.pump();

      expect(find.text('Session started'), findsOneWidget);
      expect(find.text('Upload failed'), findsOneWidget);
      expect(find.text('2 entries'), findsOneWidget);

      await tester.tap(find.widgetWithText(PrismChip, 'ERR'));
      await tester.pump();
      expect(find.text('Upload failed'), findsNothing);
      expect(find.text('1 entries'), findsOneWidget);

      await tester.tap(find.widgetWithText(PrismChip, 'ERR'));
      await tester.enterText(find.byType(TextField), 'upload');
      await tester.pump();
      expect(find.text('Session started'), findsNothing);
      expect(find.text('Upload failed'), findsOneWidget);
      expect(find.byTooltip('Clear search'), findsOneWidget);
    });

    testWidgets('a line with an error opens a detail sheet', (tester) async {
      InMemoryLogSink.instance.write(_record(1, AppLogLevel.error, 'Upload failed', tag: 'Upload', error: 'boom'));
      await tester.pumpWidget(_app(const DebugPanelPage()));
      await tester.pump();

      await tester.tap(find.text('Upload failed'));
      await tester.pumpAndSettle();

      expect(find.byType(PrismSheetBody), findsOneWidget);
      expect(find.text('Log detail'), findsOneWidget);
      expect(find.text('boom'), findsOneWidget);
      expect(find.byTooltip('Copy error'), findsOneWidget);
    });

    testWidgets('clearing the logs asks first', (tester) async {
      InMemoryLogSink.instance.write(_record(1, AppLogLevel.info, 'Session started'));
      await tester.pumpWidget(_app(const DebugPanelPage()));
      await tester.pump();

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Clear logs?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Session started'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear logs'));
      await tester.pumpAndSettle();
      expect(find.text('Session started'), findsNothing);
      expect(find.text('No logs'), findsOneWidget);
    });
  });

  group('tools tab', () {
    testWidgets('toggles a debug flag from a row and resets all flags', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const DebugPanelPage()));
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      expect(find.text('Paint size'), findsOneWidget);
      expect(DebugFlags.instance.showLogToasts, isFalse);
      await tester.tap(find.text('Show log toasts'));
      await tester.pump();
      expect(DebugFlags.instance.showLogToasts, isTrue);

      DebugFlags.instance.reset();
      await tester.pump();
      expect(DebugFlags.instance.showLogToasts, isFalse);
    });

    testWidgets('Force crash asks for confirmation and cancelling does not throw', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const DebugPanelPage()));
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Force crash'));
      await tester.pumpAndSettle();
      expect(find.text('Force crash?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('animation speed presets are chips', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const DebugPanelPage()));
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PrismChip, '2.0×'));
      await tester.pump();
      expect(DebugFlags.instance.animationSpeed, 2.0);
      DebugFlags.instance.reset();
    });
  });

  group('storage tab', () {
    late InMemoryLocalStore store;

    setUp(() {
      store = InMemoryLocalStore();
      store.data['theme.mode'] = 'Dark';
      store.data['coins'] = 12;
      PersistenceRuntime.store = store;
      getIt.registerSingleton<LocalStore>(store);
    });

    tearDown(() => getIt.unregister<LocalStore>());

    testWidgets('lists keys with a value preview and filters them', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: StorageViewerPage())));
      expect(find.byType(PrismSkeleton), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('theme.mode'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('2 keys · Backend: InMemoryLocalStore'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'coin');
      await tester.pump();
      expect(find.text('theme.mode'), findsNothing);
      expect(find.text('coins'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No keys found'), findsOneWidget);
    });

    testWidgets('deleting a key asks first, then removes it', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: StorageViewerPage())));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('Delete key?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.data.length, 2);

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete key'));
      await tester.pumpAndSettle();
      expect(store.data.length, 1);
    });

    testWidgets('tapping a key opens a sheet to edit the value', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: StorageViewerPage())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('theme.mode'));
      await tester.pumpAndSettle();
      expect(find.text('Edit value'), findsOneWidget);
      expect(find.text('Type: String'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Dark'), 'Light');
      await tester.tap(find.widgetWithText(PrismButton, 'Save'));
      await tester.pumpAndSettle();

      expect(store.data['theme.mode'], 'Light');
      expect(find.text('Edit value'), findsNothing);
    });
  });

  testWidgets('app info lists sections as grouped rows', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Prism',
      packageName: 'com.example.prism',
      version: '3.1.0',
      buildNumber: '337',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const Scaffold(body: AppInfoPage())));
    expect(find.byType(PrismSkeleton), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PrismButton, 'Copy diagnostic report'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    for (final String section in <String>['Package', 'Environment', 'User', 'Screen']) {
      expect(find.text(section), findsOneWidget);
    }
    expect(find.text('3.1.0'), findsOneWidget);
    expect(find.byType(PrismGroup), findsWidgets);
  });

  testWidgets('log toasts show warnings and above with their level label', (tester) async {
    DebugFlags.instance.showLogToasts = true;
    await tester.pumpWidget(const LogToastOverlay(child: SizedBox.shrink()));
    InMemoryLogSink.instance
      ..write(_record(1, AppLogLevel.info, 'Quiet info'))
      ..write(_record(2, AppLogLevel.warn, 'Slow query', tag: 'Firestore'));
    await tester.pump();
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();

    expect(find.text('Slow query'), findsOneWidget);
    expect(find.text('WRN'), findsOneWidget);
    expect(find.text('[Firestore]'), findsOneWidget);
    expect(find.text('Quiet info'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Slow query'), findsNothing);
  });

  group('log level colours', () {
    test('every level has its own colour', () {
      final Set<Color> colours = AppLogLevel.values.map((l) => l.color).toSet();
      expect(colours.length, AppLogLevel.values.length);
    });
  });
}
