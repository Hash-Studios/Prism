import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_analytics.dart';

const String _channelPrefix = 'dev.flutter.pigeon.Prism.PrismMediaHostApi';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late List<String> deleteCalls;
  late Future<DownloadItemsResult> Function() onList;
  late int listCalls;

  ByteData? reply(Object value) => PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[value]);

  File makeFile(String name) => File('${dir.path}/$name')..writeAsBytesSync(<int>[1, 2, 3]);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('download_screen_test');
    deleteCalls = <String>[];
    listCalls = 0;
    onList = () async => DownloadItemsResult(success: true, items: const <String>[]);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('$_channelPrefix.listDownloads', (message) async {
      listCalls++;
      return reply(await onList());
    });
    messenger.setMockMessageHandler('$_channelPrefix.deleteDownload', (message) async {
      final args = PrismMediaHostApi.pigeonChannelCodec.decodeMessage(message)! as List<Object?>;
      deleteCalls.add(args.first! as String);
      return reply(OperationResult(success: true));
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('$_channelPrefix.listDownloads', null);
    messenger.setMockMessageHandler('$_channelPrefix.deleteDownload', null);
    AnalyticsRuntime.reset();
    dir.deleteSync(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: DownloadScreen()));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows loading first, then the empty state with a browse action', (tester) async {
    final pending = Completer<DownloadItemsResult>();
    onList = () => pending.future;
    await pumpScreen(tester);
    expect(find.byType(LoadingCards), findsOneWidget);

    pending.complete(DownloadItemsResult(success: true, items: const <String>[]));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(find.text('Browse wallpapers'), findsOneWidget);
  });

  testWidgets('a failed list shows an error that Retry recovers from', (tester) async {
    onList = () async => DownloadItemsResult(success: false, items: const <String>[], message: 'no access');
    await pumpScreen(tester);
    expect(find.text("Couldn't load downloads"), findsOneWidget);

    final File file = makeFile('a.png');
    onList = () async => DownloadItemsResult(success: true, items: <String>[file.path]);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load downloads"), findsNothing);
    expect(find.text('1 download'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the files that are already shown', (tester) async {
    final File file = makeFile('a.png');
    onList = () async => DownloadItemsResult(success: true, items: <String>[file.path]);
    await pumpScreen(tester);
    expect(find.text('1 download'), findsOneWidget);

    onList = () async => DownloadItemsResult(success: false, items: const <String>[], message: 'busy');
    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(listCalls, 2);
    expect(find.text('1 download'), findsOneWidget);
    expect(find.byType(GlintState), findsNothing);
  });

  testWidgets('long press selects, Delete confirms and removes through the host API', (tester) async {
    final File a = makeFile('a.png');
    final File b = makeFile('b.png');
    final List<String> remaining = <String>[a.path, b.path];
    onList = () async => DownloadItemsResult(success: true, items: List<String>.of(remaining));
    await pumpScreen(tester);
    expect(find.text('2 downloads'), findsOneWidget);

    await tester.longPress(find.byType(InkWell).first);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    remaining.remove(a.path);
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this download?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(deleteCalls, <String>[a.path]);
    expect(find.text('1 selected'), findsNothing);
    expect(find.text('1 download'), findsOneWidget);
  });
}
