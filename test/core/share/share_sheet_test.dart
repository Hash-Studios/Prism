import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/wait_for_real_io.dart';

const String _link = 'https://prismwalls.com/share?id=wall-1';

const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

const ShareCardContent _content = ShareCardContent(
  imageUrl: 'https://img.test/full.jpg',
  link: _link,
  brandName: 'Prism',
);

/// Records every call the sheet makes outside Flutter.
class _Fake {
  _Fake(this.cards);

  final Map<ShareCardFormat, File> cards;
  final List<ShareCardFormat> renders = <ShareCardFormat>[];
  final Set<ShareCardFormat> failingFormats = <ShareCardFormat>{};
  Future<File>? pendingRender;
  Future<void>? pendingTarget;
  final List<bool> filesAvailableAtCompletion = <bool>[];
  bool instagram = false;
  bool instagramResult = true;
  final List<String> instagramPaths = <String>[];
  final List<File> saved = <File>[];
  OperationResult saveResult = OperationResult(success: true);
  final List<String> copied = <String>[];
  final List<({String text, File file})> sharedFiles = <({String text, File file})>[];
  final List<String> sharedTexts = <String>[];
  ShareResult shareResult = const ShareResult('', ShareResultStatus.success);
  bool shareFails = false;
  bool textShareFails = false;
  bool copyFails = false;

  ShareSheetServices get services => ShareSheetServices(
    render: (ShareCardFormat format, ShareCardContent content) {
      renders.add(format);
      if (pendingRender != null) return pendingRender!;
      if (failingFormats.contains(format)) return Future<File>.error(StateError('render failed'));
      return Future<File>.value(cards[format]!);
    },
    instagramAvailable: () async => instagram,
    shareToInstagram: (String path) async {
      instagramPaths.add(path);
      if (pendingTarget != null) {
        await pendingTarget;
        filesAvailableAtCompletion.add(await File(path).exists());
      }
      return instagramResult;
    },
    saveImage: (File file) async {
      saved.add(file);
      if (pendingTarget != null) {
        await pendingTarget;
        filesAvailableAtCompletion.add(await file.exists());
      }
      return saveResult;
    },
    shareFile: ({required String text, required File file, required BuildContext context}) async {
      sharedFiles.add((text: text, file: file));
      if (pendingTarget != null) {
        await pendingTarget;
        filesAvailableAtCompletion.add(await file.exists());
      }
      if (shareFails) throw PlatformException(code: 'share_failed');
      return shareResult;
    },
    shareText: ({required String text, required BuildContext context}) async {
      sharedTexts.add(text);
      if (textShareFails) throw PlatformException(code: 'text_share_failed');
      return shareResult;
    },
    copyText: (String text) async {
      if (pendingTarget != null) await pendingTarget;
      if (copyFails) throw PlatformException(code: 'clipboard_failed');
      copied.add(text);
    },
  );
}

Future<Map<ShareCardFormat, File>> _writeCards(WidgetTester tester) async {
  final Map<ShareCardFormat, File>? cards = await tester.runAsync(() async {
    final Directory dir = Directory.systemTemp.createTempSync('share_sheet_test_');
    final List<int> png = base64Decode(_pngBase64);
    return <ShareCardFormat, File>{
      for (final ShareCardFormat format in ShareCardFormat.values)
        format: File('${dir.path}/${format.name}.png')..writeAsBytesSync(png),
    };
  });
  addTearDown(() {
    final Directory dir = cards!.values.first.parent;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return cards!;
}

/// Toasts and haptics go to platform channels, so answer them here.
void _mockChannels(WidgetTester tester, {List<MethodCall>? toastCalls}) {
  final TestDefaultBinaryMessenger messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (MethodCall call) async {
    toastCalls?.add(call);
    return true;
  });
  messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

Future<void> _openSheet(WidgetTester tester, ShareSheetServices services, {VoidCallback? onShared}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: prismLightThemes.first.theme,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showShareSheet(context, _content, 'wall_detail', services: services, onShared: onShared),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
}

// The skeleton on unrendered pages animates forever, so pumpAndSettle would never return.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Finder _target(ShareTargetValue target) => find.byKey(ValueKey<ShareTargetValue>(target));

Finder _pages() => find.byKey(const ValueKey<String>('share-formats'));

void main() {
  setUp(AnalyticsRuntime.reset);
  tearDown(AnalyticsRuntime.reset);

  testWidgets('opening the sheet shows the three formats, the three targets, and renders Story once', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final _Fake fake = _Fake(await _writeCards(tester));

    await _openSheet(tester, fake.services);

    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);
    expect(_target(ShareTargetValue.copyLink), findsOneWidget);
    expect(_target(ShareTargetValue.saveImage), findsOneWidget);
    expect(_target(ShareTargetValue.more), findsOneWidget);
    expect(_target(ShareTargetValue.instagramStories), findsNothing);
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story]);
    expect(find.byKey(const ValueKey<String>('share-preview-story')), findsOneWidget);
  });

  testWidgets('swiping renders each format once, and only after it is reached', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final _Fake fake = _Fake(await _writeCards(tester));
    await _openSheet(tester, fake.services);

    await tester.drag(_pages(), const Offset(-300, 0));
    await _settle(tester);
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post]);

    await tester.drag(_pages(), const Offset(300, 0));
    await _settle(tester);
    expect(fake.renders, hasLength(2));

    await tester.drag(_pages(), const Offset(-300, 0));
    await _settle(tester);
    expect(fake.renders, hasLength(2));

    await tester.drag(_pages(), const Offset(-300, 0));
    await _settle(tester);
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post, ShareCardFormat.clean]);
    expect(find.byKey(const ValueKey<String>('share-preview-clean')), findsOneWidget);
  });

  testWidgets('Instagram target is hidden when unavailable and shares the rendered story when available', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester));

    await _openSheet(tester, fake.services);
    expect(_target(ShareTargetValue.instagramStories), findsNothing);
    await _closeSheet(tester);

    fake.instagram = true;
    await _openSheet(tester, fake.services);
    expect(_target(ShareTargetValue.instagramStories), findsOneWidget);

    await tester.tap(_target(ShareTargetValue.instagramStories));
    await _settle(tester);

    expect(fake.instagramPaths, <String>[fake.cards[ShareCardFormat.story]!.path]);
    final InviteShareResultEvent event = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(event.target, ShareTargetValue.instagramStories);
    expect(event.format, ShareFormatValue.story);
    expect(event.result, EventResultValue.success);
    expect(_target(ShareTargetValue.instagramStories), findsNothing);
  });

  testWidgets('Copy link copies the exact link, tracks it, and closes the sheet', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester));
    await _openSheet(tester, fake.services);

    await tester.tap(_target(ShareTargetValue.copyLink));
    await _settle(tester);

    expect(fake.copied, <String>[_link]);
    final InviteShareResultEvent event = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(event.channel, ShareChannelValue.link);
    expect(event.target, ShareTargetValue.copyLink);
    expect(event.result, EventResultValue.success);
    expect(event.format, ShareFormatValue.text);
    expect(_target(ShareTargetValue.copyLink), findsNothing);
  });

  testWidgets('Save image saves the selected rendered format and tracks success', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester));
    await _openSheet(tester, fake.services);

    await tester.tap(_target(ShareTargetValue.saveImage));
    await _settle(tester);

    expect(fake.saved.map((File file) => file.path), <String>[fake.cards[ShareCardFormat.story]!.path]);
    final InviteShareResultEvent event = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(event.target, ShareTargetValue.saveImage);
    expect(event.format, ShareFormatValue.story);
    expect(event.result, EventResultValue.success);
    expect(_target(ShareTargetValue.saveImage), findsNothing);
  });

  testWidgets('a failed save tracks failure and keeps the sheet open', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester))..saveResult = OperationResult(success: false);
    await _openSheet(tester, fake.services);

    await tester.tap(_target(ShareTargetValue.saveImage));
    await _settle(tester);

    final InviteShareResultEvent event = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(event.target, ShareTargetValue.saveImage);
    expect(event.result, EventResultValue.failure);
    expect(_target(ShareTargetValue.saveImage), findsOneWidget);
  });

  for (final target in [ShareTargetValue.copyLink, ShareTargetValue.saveImage, ShareTargetValue.instagramStories]) {
    testWidgets('successful $target does not prove a completed native share', (tester) async {
      _mockChannels(tester);
      final fake = _Fake(await _writeCards(tester))..instagram = true;
      int observed = 0;
      await _openSheet(tester, fake.services, onShared: () => observed++);
      await tester.tap(_target(target));
      await _settle(tester);
      expect(observed, 0);
      expect(
        target == ShareTargetValue.copyLink
            ? fake.copied
            : target == ShareTargetValue.saveImage
            ? fake.saved
            : fake.instagramPaths,
        isNotEmpty,
      );
    });
  }

  for (final status in ShareResultStatus.values) {
    testWidgets('share callback requires observed success: $status', (tester) async {
      _mockChannels(tester);
      final cards = await _writeCards(tester);
      final fake = _Fake(cards)..shareResult = ShareResult('', status);
      int observed = 0;
      await _openSheet(tester, fake.services, onShared: () => observed++);
      expect(observed, 0);
      await tester.tap(_target(ShareTargetValue.more));
      await _settle(tester);
      expect(observed, status == ShareResultStatus.success ? 1 : 0);
    });
  }

  testWidgets('More shares the rendered story with the link and tracks success', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester));
    await _openSheet(tester, fake.services);

    await tester.tap(_target(ShareTargetValue.more));
    await _settle(tester);

    expect(fake.sharedFiles, hasLength(1));
    expect(fake.sharedFiles.single.file.path, fake.cards[ShareCardFormat.story]!.path);
    expect(fake.sharedFiles.single.text, contains(_link));
    expect(fake.sharedTexts, isEmpty);
    final InviteShareResultEvent event = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(event.target, ShareTargetValue.more);
    expect(event.format, ShareFormatValue.story);
    expect(event.result, EventResultValue.success);
    expect(_target(ShareTargetValue.more), findsNothing);
  });

  testWidgets('a dismissed More share is tracked as cancelled and keeps the sheet open', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester))
      ..shareResult = const ShareResult('', ShareResultStatus.dismissed);
    await _openSheet(tester, fake.services);

    await tester.tap(_target(ShareTargetValue.more));
    await _settle(tester);

    final InviteShareResultEvent event = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(event.target, ShareTargetValue.more);
    expect(event.result, EventResultValue.cancelled);
    expect(event.reason, AnalyticsReasonValue.userCancelled);
    expect(_target(ShareTargetValue.more), findsOneWidget);
  });

  testWidgets('a failed render shows the fallback, and More shares the text link instead', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester))..failingFormats.add(ShareCardFormat.story);
    await _openSheet(tester, fake.services);

    expect(find.byKey(const ValueKey<String>('share-preview-fallback-story')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('share-preview-story')), findsNothing);

    await tester.tap(_target(ShareTargetValue.more));
    await _settle(tester);

    expect(fake.sharedFiles, isEmpty);
    expect(fake.sharedTexts, hasLength(1));
    expect(fake.sharedTexts.single, contains(_link));
    final InviteShareResultEvent event = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(event.target, ShareTargetValue.more);
    expect(event.format, ShareFormatValue.text);
    expect(event.result, EventResultValue.success);
  });

  testWidgets('closing the sheet deletes every rendered file', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final _Fake fake = _Fake(await _writeCards(tester));
    await _openSheet(tester, fake.services);

    await tester.drag(_pages(), const Offset(-300, 0));
    await _settle(tester);
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post]);

    await tester.tap(_target(ShareTargetValue.copyLink));
    await _settle(tester);
    expect(_target(ShareTargetValue.copyLink), findsNothing);

    final File story = fake.cards[ShareCardFormat.story]!;
    final File post = fake.cards[ShareCardFormat.post]!;
    await waitForRealIo(tester, () => !story.existsSync() && !post.existsSync(), reason: 'rendered files deleted');
    expect(story.existsSync(), isFalse);
    expect(post.existsSync(), isFalse);
  });

  for (final ShareTargetValue target in <ShareTargetValue>[
    ShareTargetValue.saveImage,
    ShareTargetValue.instagramStories,
    ShareTargetValue.more,
  ]) {
    testWidgets('closing while rendering for ${target.name} does not start a native target', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      _mockChannels(tester);
      final Completer<File> rendered = Completer<File>();
      final _Fake fake = _Fake(await _writeCards(tester))
        ..instagram = true
        ..pendingRender = rendered.future;
      await _openSheet(tester, fake.services);

      await tester.tap(_target(target));
      await _settle(tester);
      await _closeSheet(tester);
      final File story = fake.cards[ShareCardFormat.story]!;
      rendered.complete(story);
      await _settle(tester);
      await waitForRealIo(tester, () => !story.existsSync(), reason: 'late render deleted');

      expect(fake.saved, isEmpty);
      expect(fake.instagramPaths, isEmpty);
      expect(fake.sharedFiles, isEmpty);
      expect(fake.sharedTexts, isEmpty);
    });

    testWidgets('closing during ${target.name} keeps its file until the native target finishes', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      _mockChannels(tester);
      final Completer<void> targetFinished = Completer<void>();
      final _Fake fake = _Fake(await _writeCards(tester))
        ..instagram = true
        ..pendingTarget = targetFinished.future;
      await _openSheet(tester, fake.services);

      await waitForRealIo(
        tester,
        () => !PaintingBinding.instance.imageCache.statusForKey(FileImage(fake.cards[ShareCardFormat.story]!)).pending,
        reason: 'preview image loaded',
      );
      await tester.tap(_target(target));
      await _settle(tester);
      await _closeSheet(tester);
      await tester.runAsync(() async {
        // Let any disposal I/O finish before the native consumer reads the file.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        targetFinished.complete();
      });
      await waitForRealIo(tester, () => fake.filesAvailableAtCompletion.isNotEmpty, reason: 'native target completed');
      expect(fake.filesAvailableAtCompletion, <bool>[true]);
      final File story = fake.cards[ShareCardFormat.story]!;
      await waitForRealIo(tester, () => !story.existsSync(), reason: 'file deleted after native target finished');
    });
  }

  for (final ShareTargetValue target in <ShareTargetValue>[
    ShareTargetValue.saveImage,
    ShareTargetValue.instagramStories,
    ShareTargetValue.copyLink,
  ]) {
    testWidgets('closing during ${target.name} prevents late result toasts', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      final List<MethodCall> toastCalls = <MethodCall>[];
      _mockChannels(tester, toastCalls: toastCalls);
      final Completer<void> targetFinished = Completer<void>();
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      final _Fake fake = _Fake(await _writeCards(tester))
        ..instagram = true
        ..instagramResult = false
        ..pendingTarget = targetFinished.future;
      await _openSheet(tester, fake.services);
      await waitForRealIo(
        tester,
        () => !PaintingBinding.instance.imageCache.statusForKey(FileImage(fake.cards[ShareCardFormat.story]!)).pending,
        reason: 'preview image loaded',
      );

      await tester.tap(_target(target));
      await _settle(tester);
      await _closeSheet(tester);
      targetFinished.complete();
      await waitForRealIo(tester, () => analytics.events.isNotEmpty, reason: 'target result tracked');
      await _settle(tester);

      expect(toastCalls, isEmpty);
    });
  }

  testWidgets('a failed copy is tracked, stays open, and can be retried', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester))..copyFails = true;
    await _openSheet(tester, fake.services);

    await tester.tap(_target(ShareTargetValue.copyLink));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    final InviteShareResultEvent failure = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(failure.target, ShareTargetValue.copyLink);
    expect(failure.result, EventResultValue.failure);
    expect(failure.format, ShareFormatValue.text);
    expect(_target(ShareTargetValue.copyLink), findsOneWidget);

    fake.copyFails = false;
    await tester.tap(_target(ShareTargetValue.copyLink));
    await _settle(tester);
    expect(fake.copied, <String>[_link]);
    expect(analytics.events.whereType<InviteShareResultEvent>().last.result, EventResultValue.success);
  });

  testWidgets('a failed More image share falls back to the text link', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester))..shareFails = true;
    await _openSheet(tester, fake.services);
    await tester.drag(_pages(), const Offset(-300, 0));
    await _settle(tester);

    await tester.tap(_target(ShareTargetValue.more));
    await _settle(tester);
    final InviteShareResultEvent result = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(result.target, ShareTargetValue.more);
    expect(result.result, EventResultValue.success);
    expect(result.format, ShareFormatValue.text);
    expect(fake.sharedTexts, hasLength(1));
    expect(fake.sharedTexts.single, contains(_link));
    expect(_target(ShareTargetValue.more), findsNothing);
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post]);
  });

  testWidgets('Save image retries a failed preview render after the image becomes available', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final _Fake fake = _Fake(await _writeCards(tester))..failingFormats.add(ShareCardFormat.story);
    await _openSheet(tester, fake.services);
    expect(find.byKey(const ValueKey<String>('share-preview-fallback-story')), findsOneWidget);

    fake.failingFormats.clear();
    await tester.tap(_target(ShareTargetValue.saveImage));
    await _settle(tester);

    expect(fake.saved.map((File file) => file.path), <String>[fake.cards[ShareCardFormat.story]!.path]);
    expect(_target(ShareTargetValue.saveImage), findsNothing);
  });

  testWidgets('when both More sends fail, text failure is tracked and a retry is allowed', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester))
      ..shareFails = true
      ..textShareFails = true;
    await _openSheet(tester, fake.services);

    await tester.tap(_target(ShareTargetValue.more));
    await _settle(tester);
    final InviteShareResultEvent result = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(result.target, ShareTargetValue.more);
    expect(result.result, EventResultValue.failure);
    expect(result.format, ShareFormatValue.text);
    expect(fake.sharedTexts.single, contains(_link));
    expect(_target(ShareTargetValue.more), findsOneWidget);

    fake.textShareFails = false;
    await tester.tap(_target(ShareTargetValue.more));
    await _settle(tester);
    expect(analytics.events.whereType<InviteShareResultEvent>().last.result, EventResultValue.success);
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story]);
  });

  testWidgets('a busy save blocks double taps and other targets and retains its original format', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final Completer<void> targetFinished = Completer<void>();
    final _Fake fake = _Fake(await _writeCards(tester))
      ..saveResult = OperationResult(success: false)
      ..pendingTarget = targetFinished.future;
    await _openSheet(tester, fake.services);

    await tester.tap(_target(ShareTargetValue.saveImage));
    await _settle(tester);
    await tester.tap(_target(ShareTargetValue.saveImage));
    await tester.tap(_target(ShareTargetValue.copyLink));
    await tester.tap(_target(ShareTargetValue.more));
    await tester.drag(_pages(), const Offset(-300, 0));
    await _settle(tester);
    targetFinished.complete();
    await waitForRealIo(tester, () => analytics.events.isNotEmpty, reason: 'save result tracked');
    await _settle(tester);

    expect(fake.saved, hasLength(1));
    expect(fake.copied, isEmpty);
    expect(fake.sharedFiles, isEmpty);
    expect(analytics.events.whereType<InviteShareResultEvent>().single.format, ShareFormatValue.story);
    fake
      ..pendingTarget = null
      ..saveResult = OperationResult(success: true);
    await tester.tap(_target(ShareTargetValue.saveImage));
    await _settle(tester);
    expect(fake.saved.last.path, fake.cards[ShareCardFormat.post]!.path);
    expect(analytics.events.whereType<InviteShareResultEvent>().last.format, ShareFormatValue.post);
  });

  testWidgets('a More send failure after close is tracked without opening fallback or showing a toast', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    final List<MethodCall> toastCalls = <MethodCall>[];
    _mockChannels(tester, toastCalls: toastCalls);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final Completer<void> targetFinished = Completer<void>();
    final _Fake fake = _Fake(await _writeCards(tester))
      ..shareFails = true
      ..pendingTarget = targetFinished.future;
    await _openSheet(tester, fake.services);
    await waitForRealIo(
      tester,
      () => !PaintingBinding.instance.imageCache.statusForKey(FileImage(fake.cards[ShareCardFormat.story]!)).pending,
      reason: 'preview image loaded',
    );

    await tester.tap(_target(ShareTargetValue.more));
    await _settle(tester);
    await _closeSheet(tester);
    targetFinished.complete();
    await waitForRealIo(tester, () => fake.filesAvailableAtCompletion.isNotEmpty, reason: 'native failure completed');
    await _settle(tester);

    expect(analytics.events.whereType<InviteShareResultEvent>(), hasLength(1));
    final InviteShareResultEvent result = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(result.target, ShareTargetValue.more);
    expect(result.result, EventResultValue.failure);
    expect(result.format, ShareFormatValue.story);
    expect(fake.sharedTexts, isEmpty);
    expect(toastCalls, isEmpty);
  });

  testWidgets('every target and format exposes a semantics label', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _Fake fake = _Fake(await _writeCards(tester))..instagram = true;

    await _openSheet(tester, fake.services);

    expect(find.bySemanticsLabel('Instagram'), findsOneWidget);
    expect(find.bySemanticsLabel('Copy link'), findsOneWidget);
    expect(find.bySemanticsLabel('Save image'), findsOneWidget);
    expect(find.bySemanticsLabel('More'), findsOneWidget);
    final SemanticsNode copy = tester.getSemantics(find.bySemanticsLabel('Copy link'));
    expect(copy.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, nodeId: copy.id, viewId: tester.view.viewId),
    );
    await _settle(tester);
    expect(fake.copied, <String>[_link]);
    semantics.dispose();
  });
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(5, 5));
  await _settle(tester);
}
