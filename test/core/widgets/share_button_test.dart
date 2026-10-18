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
import '../../support/wait_for_real_io.dart';

void main() {
  setUp(AnalyticsRuntime.reset);
  tearDown(AnalyticsRuntime.reset);

  testWidgets('share calls the card share with the full image and context line, and tracks the format', (tester) async {
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;

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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

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

  testWidgets('a failed short link shares the canonical wallpaper URL', (tester) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    String? sharedLink;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://img.test/full.jpg',
            thumbUrl: 'https://img.test/thumb.jpg',
            createLink: (id, source, url, thumbUrl) async => null,
            shareCard: (BuildContext context, {required String imageUrl, required String link, String? contextLine}) {
              sharedLink = link;
              return Future<ShareCardResult>.value((format: ShareFormatValue.card, dismissed: false));
            },
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pumpAndSettle();

    expect(sharedLink, startsWith('https://prismwalls.com/share?'));
    expect(sharedLink, contains('id=wall-1'));
    expect(analytics.events.whereType<InviteShareResultEvent>().single.result, EventResultValue.success);
  });

  testWidgets('a stalled short-link request falls back without waiting for its network timeout', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final Completer<String?> link = Completer<String?>();
    String? sharedLink;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://img.test/full.jpg',
            thumbUrl: 'https://img.test/thumb.jpg',
            createLink: (id, source, url, thumbUrl) => link.future,
            shareCard: (BuildContext context, {required String imageUrl, required String link, String? contextLine}) {
              sharedLink = link;
              return Future<ShareCardResult>.value((format: ShareFormatValue.card, dismissed: false));
            },
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(sharedLink, startsWith('https://prismwalls.com/share?'));
    link.completeError(StateError('request may fail later'));
  });

  testWidgets('a bundled starter shares its local image without inventing a public wallpaper link', (tester) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    var createLinkCalls = 0;
    String? sharedImageUrl;
    String? sharedLink;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareButton(
            id: 'starter-sunset',
            source: WallpaperSource.prism,
            url: '/tmp/untrusted-starter-path.jpg',
            thumbUrl: '/tmp/untrusted-starter-path.jpg',
            createLink: (id, source, url, thumbUrl) {
              createLinkCalls++;
              return Future<String?>.value('https://prismwalls.com/share?id=$id');
            },
            shareCard: (BuildContext context, {required String imageUrl, required String link, String? contextLine}) {
              sharedImageUrl = imageUrl;
              sharedLink = link;
              return Future<ShareCardResult>.value((format: ShareFormatValue.card, dismissed: false));
            },
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Share'));
    await waitForRealIo(tester, () => sharedLink != null, reason: 'bundled wallpaper share');

    expect(createLinkCalls, 0);
    expect(sharedImageUrl, isNot('/tmp/untrusted-starter-path.jpg'));
    expect(sharedLink, contains('available in the Prism app'));
    expect(sharedLink, isNot(contains('prismwalls.com/share')));
  });
}
