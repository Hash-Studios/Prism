import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/features/pexels_feed/data/dtos/pexels_dtos.dart';
import 'package:Prism/features/pexels_feed/data/mappers/pexels_dto_mapper.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/wallhaven_feed/data/dtos/wallhaven_dtos.dart';
import 'package:Prism/features/wallhaven_feed/data/mappers/wallhaven_dto_mapper.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/wait_for_real_io.dart';

Future<ShareCardContent> _shareContent(
  WidgetTester tester, {
  String? creator,
  List<Color> palette = const <Color>[],
}) async {
  ShareCardContent? shared;
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
          creator: creator,
          palette: palette,
          createLink: (id, source, url, thumbUrl) async => 'https://prismwalls.com/share?id=$id',
          openSheet: (context, content, sourceContext) async {
            shared = content;
          },
        ),
      ),
    ),
  );
  await tester.tap(find.bySemanticsLabel('Share'));
  await tester.pumpAndSettle();
  return shared!;
}

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(AnalyticsRuntime.reset);
  tearDown(AnalyticsRuntime.reset);

  testWidgets('Prism shares pass the display derivative, never an original', (tester) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    const String thumb = 'https://legacy.test/thumb.jpg';
    const String preview =
        'https://us-central1-123.cloudfunctions.net/wallpaperPreview?id=wall-1&thumb=https%3A%2F%2Flegacy.test%2Fthumb.jpg';
    ShareCardContent? shared;
    String? linkThumbnail;
    String? sourceContext;
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
            openSheet: (context, content, source) async {
              shared = content;
              sourceContext = source;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pumpAndSettle();
    expect(shared?.imageUrl, preview);
    expect(linkThumbnail, ''); // The untrusted legacy URL is still excluded from public links.
    expect(sourceContext, 'wallpaper_screen');
  });

  testWidgets('Prism mapper original fallback is excluded from preview and public link', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    const String original = 'https://private.test/original.jpg?token=secret';
    final wallpaper = const PrismWallDocDto(wallpaperUrl: original).toDomain(docId: 'wall-1');
    ShareCardContent? shared;
    String? linkThumbnail;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShareButton(
            id: wallpaper.core.id,
            source: wallpaper.core.source,
            url: wallpaper.core.fullUrl,
            thumbUrl: wallpaper.core.thumbnailUrl,
            createLink: (id, source, url, thumbUrl) async {
              linkThumbnail = thumbUrl;
              return 'https://prismwalls.com/share?id=$id';
            },
            openSheet: (context, content, sourceContext) async => shared = content,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pumpAndSettle();

    expect(shared?.imageUrl, isEmpty);
    expect(linkThumbnail, isEmpty);
    expect(shared?.link, isNot(contains(original)));
    expect(shared?.link, isNot(contains('secret')));
  });

  for (final (String label, String sourceName, String original, String thumbnail) in <(String, String, String, String)>[
    (
      'Pexels original-only mapper fallback',
      'pexels',
      'https://pexels.test/original.jpg',
      const PexelsPhotoDto(
        id: 101,
        src: PexelsSrcDto(original: 'https://pexels.test/original.jpg'),
      ).toDomain().thumbnailUrl,
    ),
    (
      'Wallhaven missing-thumbnails mapper fallback',
      'wallhaven',
      'https://wallhaven.test/original.jpg',
      const WallhavenWallpaperDto(id: 'wh-101', path: 'https://wallhaven.test/original.jpg').toDomain().thumbnailUrl,
    ),
  ]) {
    testWidgets('$label is excluded from share card and public link', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final WallpaperSource source = sourceName == 'pexels' ? WallpaperSource.pexels : WallpaperSource.wallhaven;
      ShareCardContent? shared;
      String? linkThumbnail;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ShareButton(
              id: 'provider-101',
              source: source,
              url: original,
              thumbUrl: thumbnail,
              createLink: (id, source, url, thumbUrl) async {
                linkThumbnail = thumbUrl;
                return 'https://prismwalls.com/share?id=$id';
              },
              openSheet: (context, content, sourceContext) async => shared = content,
            ),
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Share'));
      await tester.pumpAndSettle();

      expect(shared?.imageUrl, isEmpty);
      expect(linkThumbnail, isEmpty);
    });
  }

  testWidgets('provider originals compare after trimming while safe derivatives remain shareable', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final List<String?> imageUrls = <String?>[];
    final List<String?> linkThumbnails = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: <Widget>[
              ShareButton(
                id: 'wh-whitespace',
                source: WallpaperSource.wallhaven,
                url: ' https://wallhaven.test/original.jpg ',
                thumbUrl: '  https://wallhaven.test/original.jpg  ',
                createLink: (id, source, url, thumbUrl) async {
                  linkThumbnails.add(thumbUrl);
                  return 'https://prismwalls.com/share?id=$id';
                },
                openSheet: (context, content, sourceContext) async => imageUrls.add(content.imageUrl),
              ),
              ShareButton(
                id: 'pexels-derivative',
                source: WallpaperSource.pexels,
                url: 'https://pexels.test/original.jpg',
                thumbUrl: 'https://images.pexels.test/thumbnail.jpg',
                createLink: (id, source, url, thumbUrl) async {
                  linkThumbnails.add(thumbUrl);
                  return 'https://prismwalls.com/share?id=$id';
                },
                openSheet: (context, content, sourceContext) async => imageUrls.add(content.imageUrl),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Share').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Share').last);
    await tester.pumpAndSettle();

    expect(imageUrls, <String?>['', 'https://images.pexels.test/thumbnail.jpg']);
    expect(linkThumbnails, <String?>['', 'https://images.pexels.test/thumbnail.jpg']);
  });

  testWidgets('share uses the Prism display derivative and context line', (tester) async {
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;

    ShareCardContent? shared;
    String? sourceContext;
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
            contextLine: 'by Akshay',
            createLink: (id, source, url, thumbUrl) async => 'https://prismwalls.com/share?id=$id',
            openSheet: (BuildContext context, ShareCardContent content, String source) async {
              shared = content;
              sourceContext = source;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pumpAndSettle();

    expect(
      shared?.imageUrl,
      'https://us-central1-123.cloudfunctions.net/wallpaperPreview?id=wall-1&thumb=https%3A%2F%2Fimg.test%2Fthumb.jpg',
    );
    expect(shared?.contextLine, 'by Akshay');
    expect(sourceContext, 'wallpaper_screen');
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
            openSheet: (BuildContext context, ShareCardContent content, String sourceContext) {
              shareCalls++;
              return Future<void>.value();
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
                openSheet: (BuildContext context, ShareCardContent content, String sourceContext) {
                  currentCalls.addAll(<String?>[content.imageUrl, content.link, content.contextLine]);
                  return Future<void>.value();
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
            openSheet: (BuildContext context, ShareCardContent content, String sourceContext) {
              sharedImageUrl = content.imageUrl;
              return Future<void>.value();
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
            openSheet: (BuildContext context, ShareCardContent content, String sourceContext) {
              sharedLink = content.link;
              return Future<void>.value();
            },
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pumpAndSettle();

    expect(sharedLink, startsWith('https://prismwalls.com/share?'));
    expect(sharedLink, contains('id=wall-1'));
    expect(analytics.events.whereType<InviteShareResultEvent>(), isEmpty);
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
            openSheet: (BuildContext context, ShareCardContent content, String sourceContext) {
              sharedLink = content.link;
              return Future<void>.value();
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
            openSheet: (BuildContext context, ShareCardContent content, String sourceContext) {
              sharedLink = content.link;
              return Future<void>.value();
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
            openSheet: (BuildContext context, ShareCardContent content, String sourceContext) {
              sharedImageUrl = content.imageUrl;
              sharedLink = content.link;
              return Future<void>.value();
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

  testWidgets('the share card credits a one-word creator as a handle', (tester) async {
    final ShareCardContent content = await _shareContent(tester, creator: 'maya');

    expect(content.creator, '@maya');
    expect(content.creatorLine, 'by @maya');
  });

  testWidgets('an email address is never shown as the creator', (tester) async {
    final ShareCardContent content = await _shareContent(tester, creator: 'a@b.com');

    expect(content.creator, isNull);
    expect(content.creatorLine, isNull);
  });

  testWidgets('the stored wall colours pass through unchanged as the palette', (tester) async {
    const List<Color> palette = <Color>[Color(0xFF0066CC), Color(0xFFEA4C88)];
    final ShareCardContent content = await _shareContent(tester, palette: palette);

    expect(content.palette, palette);
  });
}
