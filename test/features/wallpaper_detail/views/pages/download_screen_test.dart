import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_analytics.dart';

const BasicMessageChannel<Object?> _listChannel = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
  PrismMediaHostApi.pigeonChannelCodec,
);

/// Glint loops forever, so the screen never reaches a still frame: pump a fixed time instead of settling.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late int listCalls;

  setUp(() {
    listCalls = 0;
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      _listChannel,
      null,
    );
  });

  void answerWith(Future<DownloadItemsResult> Function() reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      _listChannel,
      (_) async {
        listCalls++;
        return <Object?>[await reply()];
      },
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: DownloadScreen()));
  }

  testWidgets('shows a skeleton grid while the list loads', (tester) async {
    final Completer<DownloadItemsResult> gate = Completer<DownloadItemsResult>();
    answerWith(() => gate.future);

    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('Downloads'), findsOneWidget);
    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.text('No downloads yet'), findsNothing);

    gate.complete(DownloadItemsResult(success: true, items: <String>[]));
    await _settle(tester);
    expect(find.byType(LoadingCards), findsNothing);
  });

  testWidgets('empty state is Glint with a way to browse, not an illustration', (tester) async {
    answerWith(() async => DownloadItemsResult(success: true, items: <String>[]));

    await pumpScreen(tester);
    await _settle(tester);

    expect(find.text('No downloads yet'), findsOneWidget);
    expect(find.text('Wallpapers you download are kept here.'), findsOneWidget);
    expect(find.text('Browse wallpapers'), findsOneWidget);
    expect(find.byType(Glint), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('error state offers Try again and reloads the list', (tester) async {
    answerWith(() async => DownloadItemsResult(success: false, items: <String>[], message: 'no access'));

    await pumpScreen(tester);
    await _settle(tester);

    expect(find.text("Couldn't load your downloads"), findsOneWidget);
    expect(listCalls, 1);

    await tester.tap(find.text('Try again'));
    await _settle(tester);

    expect(listCalls, 2);
  });

  testWidgets('downloaded files fill the shared wallpaper grid', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('downloads_screen_test_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final List<String> paths = <String>[
      for (int i = 0; i < 2; i++) (File('${directory.path}/wall_$i.png')..writeAsBytesSync(<int>[1, 2, 3])).path,
    ];
    answerWith(() async => DownloadItemsResult(success: true, items: paths));

    await pumpScreen(tester);
    await _settle(tester);

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('No downloads yet'), findsNothing);
  });
}
