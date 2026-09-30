import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  testWidgets('share calls the card share with the full image and context line, and tracks the format', (tester) async {
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);

    final List<String?> calls = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://img.test/full.jpg',
            thumbUrl: 'https://img.test/thumb.jpg',
            contextLine: 'by Akshay',
            createLink: (id, source, url, thumbUrl) async => 'https://prismwalls.com/share?id=$id',
            shareCard:
                (BuildContext context, {required String imageUrl, required String link, String? contextLine}) async {
                  calls
                    ..add(imageUrl)
                    ..add(contextLine);
                  return (format: ShareFormatValue.card, dismissed: false);
                },
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump(const Duration(seconds: 1));

    expect(calls, <String?>['https://img.test/full.jpg', 'by Akshay']);
    final InviteShareResultEvent result = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(result.format, ShareFormatValue.card);
    expect(result.toWireParameters()['format'], 'card');
  });

  testWidgets('a dismissed share sheet is tracked as cancelled', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://img.test/full.jpg',
            thumbUrl: 'https://img.test/thumb.jpg',
            createLink: (id, source, url, thumbUrl) async => 'https://prismwalls.com/share?id=$id',
            shareCard:
                (BuildContext context, {required String imageUrl, required String link, String? contextLine}) async =>
                    (format: ShareFormatValue.text, dismissed: true),
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump(const Duration(seconds: 1));

    final InviteShareResultEvent result = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(result.result, EventResultValue.cancelled);
    expect(result.reason, AnalyticsReasonValue.userCancelled);
    expect(result.format, ShareFormatValue.text);
  });

  testWidgets('a second tap does not start another share while the first is pending', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final Completer<String> link = Completer<String>();
    var linkCalls = 0;
    var shareCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://img.test/full.jpg',
            thumbUrl: 'https://img.test/thumb.jpg',
            createLink: (id, source, url, thumbUrl) {
              linkCalls++;
              return link.future;
            },
            shareCard: (BuildContext context, {required String imageUrl, required String link, String? contextLine}) {
              shareCalls++;
              return Future<ShareCardResult>.value((format: ShareFormatValue.card, dismissed: false));
            },
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pump();

    expect(linkCalls, 1);
    link.complete('https://prismwalls.com/share?id=wall-1');
    await tester.pump();
    await tester.pump();
    expect(shareCalls, 1);
  });

  testWidgets('a pending share uses the wallpaper values captured when tapped', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final Completer<String> link = Completer<String>();
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);
    final List<String?> firstShare = <String?>[];
    final List<String?> secondShare = <String?>[];
    final Key buttonKey = UniqueKey();
    var id = 'wall-1';
    var image = 'https://img.test/one.jpg';
    var contextLine = 'by One';
    var calls = firstShare;
    late void Function(void Function()) update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            final List<String?> currentCalls = calls;
            return Scaffold(
              body: ShareButton(
                key: buttonKey,
                id: id,
                source: WallpaperSource.prism,
                url: image,
                thumbUrl: '$image-thumb',
                contextLine: contextLine,
                createLink: (id, source, url, thumbUrl) => link.future,
                shareCard:
                    (BuildContext context, {required String imageUrl, required String link, String? contextLine}) {
                      currentCalls.addAll(<String?>[imageUrl, link, contextLine]);
                      return Future<ShareCardResult>.value((format: ShareFormatValue.card, dismissed: false));
                    },
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pump();

    update(() {
      id = 'wall-2';
      image = 'https://img.test/two.jpg';
      contextLine = 'by Two';
      calls = secondShare;
    });
    await tester.pump();
    link.complete('https://prismwalls.com/share?id=wall-1');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();

    expect(secondShare, isEmpty);
    expect(firstShare, <String?>['https://img.test/one.jpg', 'https://prismwalls.com/share?id=wall-1', 'by One']);
    expect(analytics.events.whereType<InviteShareResultEvent>().single.format, ShareFormatValue.card);
  });

  testWidgets('a share that finishes after the button is removed is not tracked as successful', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);
    final Completer<ShareCardResult> share = Completer<ShareCardResult>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://img.test/full.jpg',
            thumbUrl: 'https://img.test/thumb.jpg',
            createLink: (id, source, url, thumbUrl) async => 'https://prismwalls.com/share?id=$id',
            shareCard: (BuildContext context, {required String imageUrl, required String link, String? contextLine}) =>
                share.future,
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    share.complete((format: ShareFormatValue.card, dismissed: false));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();

    expect(analytics.events.whereType<InviteShareResultEvent>(), isEmpty);
  });

  testWidgets('an empty full image URL falls back to the thumbnail', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final Completer<String> link = Completer<String>()..complete('https://prismwalls.com/share?id=wall-1');
    String? sharedImageUrl;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: '',
            thumbUrl: ' https://img.test/thumb.jpg ',
            createLink: (id, source, url, thumbUrl) => link.future,
            shareCard: (BuildContext context, {required String imageUrl, required String link, String? contextLine}) {
              sharedImageUrl = imageUrl;
              return Future<ShareCardResult>.value((format: ShareFormatValue.card, dismissed: false));
            },
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pump();
    await tester.pump();

    expect(sharedImageUrl, 'https://img.test/thumb.jpg');
  });
}
