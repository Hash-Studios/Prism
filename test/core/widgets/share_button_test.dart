import 'dart:async';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:share_plus/share_plus.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/offline_asset_fixture.dart';
import '../../support/wait_for_real_io.dart';

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(AnalyticsRuntime.reset);
  tearDown(AnalyticsRuntime.reset);

  testWidgets('Prism shares render a real card from the display derivative, never an original', (tester) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    const String thumb = 'https://legacy.test/thumb.jpg';
    const String preview =
        'https://us-central1-123.cloudfunctions.net/wallpaperPreview?id=wall-1&thumb=https%3A%2F%2Flegacy.test%2Fthumb.jpg';
    late OfflineAssetFixture assets;
    await tester.runAsync(() async {
      assets = await OfflineAssetFixture.create(cacheMissByDefault: true);
      assets.install();
      final derivative = await assets.cachedImageFor(preview);
      when(() => assets.cacheManager.getSingleFile(preview)).thenAnswer((_) async => derivative);
    });
    addTearDown(assets.dispose);
    ShareCardResult? shared;
    String? linkThumbnail;
    String? renderedSource;
    (int, int)? sentSize;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://private.test/original.jpg?token=secret',
            thumbUrl: thumb,
            createLink: (id, source, url, thumbUrl) async {
              linkThumbnail = thumbUrl;
              return 'https://prismwalls.com/share?id=wall-1';
            },
            shareCard: (context, {required imageUrl, required link, contextLine}) async {
              renderedSource = imageUrl;
              return shared = await shareWallpaperCard(
                context,
                imageUrl: imageUrl,
                link: link,
                sendCard: ({required text, required file, required context}) async {
                  final ui.Codec codec = await ui.instantiateImageCodec(await file.readAsBytes());
                  final ui.Image image = (await codec.getNextFrame()).image;
                  sentSize = (image.width, image.height);
                  image.dispose();
                  codec.dispose();
                  return const ShareResult('', ShareResultStatus.success);
                },
                sendText: ({required text, required context}) async => const ShareResult('', ShareResultStatus.success),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Share'));
    await waitForRealIo(tester, () => shared != null, reason: 'Prism display derivative share card');
    expect(renderedSource, preview);
    expect(linkThumbnail, ''); // The untrusted legacy URL is still excluded from public links.
    expect(shared, (format: ShareFormatValue.card, dismissed: false));
    expect(sentSize, (1080, 1920));
    expect(analytics.events.whereType<InviteShareResultEvent>().single.format, ShareFormatValue.card);
  });

  testWidgets('share uses the Prism display derivative and context line, and tracks the format', (tester) async {
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://img.test/full.jpg',
            thumbUrl: 'https://img.test/full.jpg',
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

    expect(calls, <String?>[
      'https://us-central1-123.cloudfunctions.net/wallpaperPreview?id=wall-1&thumb=https%3A%2F%2Fimg.test%2Ffull.jpg',
      'by Akshay',
    ]);
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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
    expect(firstShare, <String?>[
      'https://us-central1-123.cloudfunctions.net/wallpaperPreview?id=wall-1&thumb=https%3A%2F%2Fimg.test%2Fone.jpg-thumb',
      'https://prismwalls.com/share?id=wall-1',
      'by One',
    ]);
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    share.complete((format: ShareFormatValue.card, dismissed: false));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();

    expect(analytics.events.whereType<InviteShareResultEvent>(), isEmpty);
  });

  testWidgets('a missing thumbnail never falls back to the original', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final Completer<String> link = Completer<String>()..complete('https://prismwalls.com/share?id=wall-1');
    String? sharedImageUrl;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://private.test/premium-original.jpg',
            thumbUrl: '',
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

    expect(sharedImageUrl, isEmpty);
  });

  testWidgets('a failed short link shares the canonical wallpaper URL', (tester) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    String? sharedLink;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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

  testWidgets('a short link that takes longer than 750 ms is used for sharing', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final Completer<String?> link = Completer<String?>();
    String? sharedLink;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShareButton(
            id: 'EY3F',
            source: WallpaperSource.prism,
            url: null,
            thumbUrl: '',
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
    await tester.pump(const Duration(seconds: 2));

    link.complete('https://prismwalls.com/l/short123');
    await tester.pumpAndSettle();

    expect(sharedLink, 'https://prismwalls.com/l/short123');
  });

  testWidgets('a stalled short-link request falls back after the six-second request budget', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final Completer<String?> link = Completer<String?>();
    String? sharedLink;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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
    await tester.pump(const Duration(seconds: 5));

    expect(sharedLink, isNull);
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

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
