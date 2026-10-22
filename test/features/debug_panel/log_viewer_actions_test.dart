import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/features/debug_panel/views/pages/log_viewer_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sink = InMemoryLogSink.instance;
  late List<String> copied;
  setUp(() {
    sink.clear();
    copied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      },
    );
  });
  tearDown(() {
    sink.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: LogViewerPage()),
    ),
  );

  testWidgets('copy and detail preserve diagnostics, search and tag filters select the exported records', (
    tester,
  ) async {
    sink.write(
      AppLogRecord(
        sequence: 12,
        timestamp: DateTime.utc(2026, 10, 20, 10, 11, 12),
        level: AppLogLevel.error,
        message: 'Download failed',
        tag: 'network',
        error: 'offline',
        stackTrace: StackTrace.fromString('fetchWall:42'),
        fields: const {'wallId': 'wall-123', 'retry': null},
      ),
    );
    sink.write(
      AppLogRecord(
        sequence: 13,
        timestamp: DateTime.utc(2026),
        level: AppLogLevel.info,
        message: 'Cached wallpaper',
        tag: 'cache',
      ),
    );
    await pump(tester);
    await tester.tap(find.byTooltip('Copy all (filtered)'));
    await tester.pump();
    expect(copied.single, contains('ERR [network] Download failed'));
    expect(copied.single, contains('ERROR: offline'));
    expect(copied.single, contains('STACK: fetchWall:42'));
    expect(copied.single, contains('FIELDS: {wallId: wall-123, retry: null}'));

    await tester.tap(find.text('Download failed'));
    await tester.pumpAndSettle();
    expect(find.text('#12'), findsOneWidget);
    expect(find.text('wall-123'), findsOneWidget);
    await tester.tap(find.text('Copy full detail'));
    await tester.pump();
    expect(copied.last, contains('Level: error'));
    expect(copied.last, contains('Tag: network'));
    expect(copied.last, contains('StackTrace:\nfetchWall:42'));
    await tester.tap(find.byTooltip('Copy error'));
    await tester.pump();
    expect(copied.last, 'offline');
    await tester.tap(find.byTooltip('Copy stack trace'));
    await tester.pump();
    expect(copied.last, 'fetchWall:42');
    Navigator.of(tester.element(find.text('Copy full detail'))).pop();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'CACHED');
    await tester.pump();
    expect(find.text('Cached wallpaper'), findsOneWidget);
    expect(find.text('Download failed'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('All tags'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('network').last);
    await tester.pumpAndSettle();
    expect(find.text('Cached wallpaper'), findsNothing);
    await tester.tap(find.byTooltip('Copy all (filtered)'));
    await tester.pump();
    expect(copied.last, isNot(contains('Cached wallpaper')));
    expect(copied.last, contains('Download failed'));
  });

  testWidgets('clear requires confirmation and new logs arrive after clearing', (tester) async {
    sink.write(AppLogRecord(sequence: 1, timestamp: DateTime.utc(2026), level: AppLogLevel.info, message: 'old'));
    await pump(tester);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear logs?'), findsOneWidget);
    expect(sink.records, hasLength(1));
    await tester.tap(find.text('Clear').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(sink.records, isEmpty);
    expect(find.text('old'), findsNothing);
    sink.write(AppLogRecord(sequence: 2, timestamp: DateTime.utc(2026), level: AppLogLevel.warn, message: 'new'));
    await tester.pump();
    await tester.pump();
    expect(find.text('new'), findsOneWidget);
    await tester.tap(find.byTooltip('Turn off auto-scroll'));
    await tester.pump();
    expect(find.byTooltip('Turn on auto-scroll'), findsOneWidget);
  });
}
