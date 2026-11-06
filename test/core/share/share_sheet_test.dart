import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

Future<void> _openSheet(
  WidgetTester tester,
  ShareSheetServices services, {
  ShareCardContent content = _content,
  Future<ShareCardContent?>? ready,
  VoidCallback? onShared,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
  double? textScale,
  bool boldText = false,
  TextDirection? direction,
  double? letterSpacing,
}) async {
  if (boldText) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  if (disableAnimations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: prismLightThemes.first.theme,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        final Widget scaledChild = textScale == null && letterSpacing == null
            ? child!
            : MediaQuery(
                data: media
                    .applyTextStyleOverrides(
                      lineHeightScaleFactorOverride: media.lineHeightScaleFactorOverride,
                      letterSpacingOverride: letterSpacing ?? media.letterSpacingOverride,
                      wordSpacingOverride: media.wordSpacingOverride,
                      paragraphSpacingOverride: media.paragraphSpacingOverride,
                    )
                    .copyWith(textScaler: textScale == null ? media.textScaler : TextScaler.linear(textScale)),
                child: child!,
              );
        return direction == null ? scaledChild : Directionality(textDirection: direction, child: scaledChild);
      },
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showShareSheet(context, content, 'wall_detail', ready: ready, services: services, onShared: onShared),
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

Future<void> _loadShareTargetFonts(WidgetTester tester) async {
  final FontLoader loader = FontLoader('Proxima Nova')
    ..addFont(rootBundle.load('assets/fonts/ProximaNova-Regular.otf'))
    ..addFont(rootBundle.load('assets/fonts/Proxima Nova Extrabold.otf'));
  await tester.runAsync(loader.load);
}

void _expectWholeWords(RenderParagraph paragraph, {required String reason}) {
  final String text = paragraph.text.toPlainText();
  expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
  for (final RegExpMatch word in RegExp(r'\S+').allMatches(text)) {
    final List<TextBox> boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    expect(boxes, isNotEmpty, reason: '$reason missing geometry for "${word.group(0)}"');
    expect(boxes.map((TextBox box) => box.top).toSet(), hasLength(1), reason: '$reason split word "${word.group(0)}"');
    expect(
      boxes.every((TextBox box) => box.left >= -0.01 && box.right <= paragraph.size.width + 0.01),
      isTrue,
      reason: '$reason word "${word.group(0)}" exceeds paragraph bounds',
    );
  }
}

// The skeleton on unrendered pages animates forever, so pumpAndSettle would never return.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Finder _target(ShareTargetValue target) => find.byKey(ValueKey<ShareTargetValue>(target));

Finder _pages() => find.byKey(const ValueKey<String>('share-formats'));

void main() {
  setUp(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user'
      ..loggedIn = true;
  });
  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  testWidgets('a pending share opens on the wall colour, renders once ready, and a target waits for it', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    const Color wall = Color(0xFF0066CC);
    const String shortLink = 'https://prismwalls.com/l/short123';
    final Completer<ShareCardContent?> ready = Completer<ShareCardContent?>();
    final _Fake fake = _Fake(await _writeCards(tester));
    await _openSheet(
      tester,
      fake.services,
      content: const ShareCardContent(
        imageUrl: 'https://img.test/full.jpg',
        link: _link,
        brandName: 'Prism',
        palette: <Color>[wall],
      ),
      ready: ready.future,
    );

    expect(find.text('Story'), findsOneWidget);
    expect(fake.renders, isEmpty);
    expect(
      tester.widget<ColoredBox>(find.byKey(const ValueKey<String>('share-preview-placeholder-story'))).color,
      wall,
    );

    await tester.tap(_target(ShareTargetValue.copyLink));
    await tester.pump();
    expect(fake.copied, isEmpty);

    ready.complete(
      const ShareCardContent(
        imageUrl: 'https://img.test/full.jpg',
        link: shortLink,
        brandName: 'Prism',
        palette: <Color>[wall],
      ),
    );
    await _settle(tester);

    expect(fake.copied, <String>[shortLink]);
    expect(fake.renders, contains(ShareCardFormat.story));
  });

  testWidgets('a pending share that cannot load closes the sheet', (tester) async {
    _mockChannels(tester);
    final Completer<ShareCardContent?> ready = Completer<ShareCardContent?>();
    final _Fake fake = _Fake(await _writeCards(tester));
    await _openSheet(tester, fake.services, ready: ready.future);
    expect(find.text('Story'), findsOneWidget);

    ready.complete(null);
    await _settle(tester);

    expect(find.text('Story'), findsNothing);
    expect(fake.renders, isEmpty);
  });

  testWidgets('cancelling sign-in does not copy or save a share card', (tester) async {
    _mockChannels(tester);
    final fake = _Fake(await _writeCards(tester));
    await _openSheet(tester, fake.services);
    app_state.prismUser = app_constants.createGuestPrismUser();
    final original = signedInActionSignIn;
    var prompts = 0;
    signedInActionSignIn = (_) async {
      prompts++;
      return false;
    };
    addTearDown(() => signedInActionSignIn = original);

    await tester.tap(_target(ShareTargetValue.copyLink));
    await _settle(tester);
    await tester.tap(_target(ShareTargetValue.saveImage));
    await _settle(tester);

    expect(prompts, 2);
    expect(fake.copied, isEmpty);
    expect(fake.saved, isEmpty);
  });

  testWidgets('signing out while rendering prevents saving the image', (tester) async {
    _mockChannels(tester);
    final rendered = Completer<File>();
    final fake = _Fake(await _writeCards(tester))..pendingRender = rendered.future;
    await _openSheet(tester, fake.services);
    await tester.tap(_target(ShareTargetValue.saveImage));
    await tester.pump();
    app_state.prismUser = app_constants.createGuestPrismUser();
    rendered.complete(fake.cards[ShareCardFormat.story]!);
    await _settle(tester);
    expect(fake.saved, isEmpty);
  });

  testWidgets('Duo opens its own card first and tracks only a successful render once', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester));
    await _openSheet(
      tester,
      fake.services,
      content: const ShareCardContent(
        imageUrl: 'https://img.test/full.jpg',
        link: _link,
        brandName: 'Prism',
        duoReveal: true,
        contentId: 'duo-wall',
        foldedLabel: 'Folded',
        unfoldedLabel: 'Unfolded',
        cta: 'Get it on Prism',
      ),
    );
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.duoReveal, ShareCardFormat.story]);
    expect(analytics.events.whereType<DuoShareCardMadeEvent>(), hasLength(1));
    await tester.tap(_target(ShareTargetValue.saveImage));
    await _settle(tester);
    expect(fake.saved.single.path, fake.cards[ShareCardFormat.duoReveal]!.path);
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.duoReveal, ShareCardFormat.story]);
    expect(analytics.events.whereType<DuoShareCardMadeEvent>(), hasLength(1));
  });

  testWidgets('opening the sheet shows the three formats, the three targets, and renders Story and the peeking Post', (
    tester,
  ) async {
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
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post]);
    expect(find.byKey(const ValueKey<String>('share-preview-story')), findsOneWidget);
  });

  testWidgets('swiping renders each format once, once it or its neighbour is reached', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final _Fake fake = _Fake(await _writeCards(tester));
    await _openSheet(tester, fake.services);

    await tester.drag(_pages(), const Offset(-300, 0));
    await _settle(tester);
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post, ShareCardFormat.clean]);

    await tester.drag(_pages(), const Offset(300, 0));
    await _settle(tester);
    expect(fake.renders, hasLength(3));

    await tester.drag(_pages(), const Offset(-300, 0));
    await _settle(tester);
    expect(fake.renders, hasLength(3));

    await tester.drag(_pages(), const Offset(-300, 0));
    await _settle(tester);
    expect(fake.renders, hasLength(3));
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
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post, ShareCardFormat.clean]);

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
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post, ShareCardFormat.clean]);
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
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post]);
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

  testWidgets('tapping a format with reduced motion selects it while the preview is still loading', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final Completer<File> pending = Completer<File>();
    final _Fake fake = _Fake(await _writeCards(tester))..pendingRender = pending.future;

    await _openSheet(tester, fake.services, disableAnimations: true);
    expect(_formatSemantics('Story'), findsOneWidget);
    expect(tester.widget<Semantics>(_formatSemantics('Story')).properties.selected, isTrue);
    expect(tester.widget<Semantics>(_formatSemantics('Post')).properties.selected, isFalse);

    await tester.tapAt(_rightFormatPeek(tester));
    await _settle(tester);

    expect(tester.widget<Semantics>(_formatSemantics('Post')).properties.selected, isTrue);
    expect(find.byKey(const ValueKey<String>('share-preview-post')), findsNothing);
    expect(fake.renders, <ShareCardFormat>[ShareCardFormat.story, ShareCardFormat.post, ShareCardFormat.clean]);
  });
  testWidgets('Open on computer target shows with a computer link and opens the link sheet', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final _Fake fake = _Fake(await _writeCards(tester));
    final ShareCardContent content = ShareCardContent(
      imageUrl: 'https://img.test/full.jpg',
      link: _link,
      brandName: 'Prism',
      computerLink: Uri.parse('https://prismwalls.com/l/Ab3dEf7h?d=1'),
    );
    await _openSheet(tester, fake.services, content: content);

    final Finder target = _target(ShareTargetValue.openOnComputer);
    expect(target, findsOneWidget);
    expect(find.descendant(of: target, matching: find.text('Open on computer')), findsOneWidget);

    await tester.tap(target);
    await _settle(tester);

    expect(
      tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('open-on-computer-link')),
              matching: find.byType(Text),
            ),
          )
          .map((Text text) => text.data)
          .join(),
      'prismwalls.com/l/Ab3dEf7h?d=1',
    );
  });

  testWidgets('Open on computer target label stays readable at large text in a narrow sheet', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 720);
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    _mockChannels(tester);
    final _Fake fake = _Fake(await _writeCards(tester));
    final ShareCardContent content = ShareCardContent(
      imageUrl: 'https://img.test/full.jpg',
      link: _link,
      brandName: 'Prism',
      computerLink: Uri.parse('https://prismwalls.com/l/Ab3dEf7h?d=1'),
    );
    await _openSheet(tester, fake.services, content: content);

    final Finder label = find.text('Open on computer');
    expect(label, findsOneWidget);
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(label);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);

    const String text = 'Open on computer';
    final TextPainter painter = TextPainter(
      text: paragraph.text,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: paragraph.textScaler,
    )..layout(maxWidth: paragraph.constraints.maxWidth);
    final List<String> lines = <String>[];
    int offset = 0;
    while (offset < text.length) {
      final TextRange line = painter.getLineBoundary(TextPosition(offset: offset));
      lines.add(text.substring(line.start, line.end).trim());
      offset = line.end <= offset ? offset + 1 : line.end;
      while (offset < text.length && text[offset] == ' ') {
        offset++;
      }
    }
    painter.dispose();
    expect(lines.length, greaterThan(1), reason: 'the label wraps at 3x in a 320 px sheet');
    for (final String line in lines) {
      expect(
        line.split(' ').every(<String>['Open', 'on', 'computer'].contains),
        isTrue,
        reason: 'line "$line" cut a word',
      );
    }
  });

  testWidgets('without a computer link the Open on computer target is absent and Copy link stays', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final _Fake fake = _Fake(await _writeCards(tester));

    await _openSheet(tester, fake.services);

    expect(_target(ShareTargetValue.openOnComputer), findsNothing);
    expect(_target(ShareTargetValue.copyLink), findsOneWidget);
  });

  testWidgets('all share target labels stay whole across locales, directions, widths, and text scales', (tester) async {
    await _loadShareTargetFonts(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final _Fake fake = _Fake(await _writeCards(tester))
      ..instagram = true
      ..pendingRender = Completer<File>().future;
    const List<Locale> locales = <Locale>[
      Locale('de'),
      Locale('es'),
      Locale('hi'),
      Locale('id'),
      Locale('pt'),
      Locale('pt', 'BR'),
      Locale('en'),
    ];
    const List<double> scales = <double>[1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3];
    const List<ShareTargetValue> targets = <ShareTargetValue>[
      ShareTargetValue.instagramStories,
      ShareTargetValue.copyLink,
      ShareTargetValue.openOnComputer,
      ShareTargetValue.saveImage,
      ShareTargetValue.more,
    ];
    final Set<String> oneXShrinks = <String>{};
    for (final Locale locale in locales) {
      final AppLocalizations l10n = await loadAppLocalizations(locale);
      final List<String> labels = <String>[
        l10n.coreShareTargetInstagram,
        l10n.coreShareTargetCopyLink,
        l10n.coreShareOpenOnComputer,
        l10n.coreShareTargetSaveImage,
        l10n.coreShareTargetMore,
      ];
      for (final TextDirection direction in TextDirection.values) {
        for (final double width in <double>[320, 400]) {
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = Size(width, 900);
          for (final double scale in scales) {
            await _openSheet(
              tester,
              fake.services,
              locale: locale,
              textScale: scale,
              direction: direction,
              content: ShareCardContent(
                imageUrl: 'https://img.test/full.jpg',
                link: _link,
                brandName: 'Prism',
                computerLink: Uri.parse(_link),
              ),
            );
            for (var i = 0; i < targets.length; i++) {
              final Finder target = _target(targets[i]);
              expect(target, findsOneWidget, reason: '${locale.toLanguageTag()} width=$width scale=$scale');
              expect(find.bySemanticsLabel(labels[i]), findsOneWidget);
              final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(of: target, matching: find.byType(Text)),
              );
              final String text = paragraph.text.toPlainText();
              expect(text, labels[i], reason: 'unmodified label for ${targets[i]} / ${locale.toLanguageTag()}');
              expect(paragraph.textDirection, direction);
              _expectWholeWords(
                paragraph,
                reason: '${targets[i]} / ${locale.toLanguageTag()} width=$width scale=$scale direction=$direction',
              );
              expect(paragraph.textScaler.scale(12), lessThanOrEqualTo(scale * 12 + 0.01));
              if (width == 400 && scale == 1 && paragraph.textScaler.scale(12) != 12) {
                oneXShrinks.add('${locale.toLanguageTag()}/${targets[i].name}');
              }
            }
            await _closeSheet(tester);
          }
        }
      }
    }
    expect(oneXShrinks, <String>{'pt/openOnComputer', 'pt-BR/openOnComputer'});
    semantics.dispose();
  });

  for (final ({String name, bool boldText, double? letterSpacing}) accessibilityCase
      in <({String name, bool boldText, double? letterSpacing})>[
        (name: 'bold text', boldText: true, letterSpacing: null),
        (name: 'increased letter spacing', boldText: false, letterSpacing: 2),
      ]) {
    testWidgets('${accessibilityCase.name} does not split German target words', (tester) async {
      await _loadShareTargetFonts(tester);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);
      final SemanticsHandle semantics = tester.ensureSemantics();
      _mockChannels(tester);
      final _Fake fake = _Fake(await _writeCards(tester))
        ..instagram = true
        ..pendingRender = Completer<File>().future;
      await _openSheet(
        tester,
        fake.services,
        locale: const Locale('de'),
        textScale: 3,
        boldText: accessibilityCase.boldText,
        letterSpacing: accessibilityCase.letterSpacing,
        content: ShareCardContent(imageUrl: '', link: _link, brandName: 'Prism', computerLink: Uri.parse(_link)),
      );
      final AppLocalizations l10n = await loadAppLocalizations(const Locale('de'));
      for (final ShareTargetValue target in <ShareTargetValue>[
        ShareTargetValue.instagramStories,
        ShareTargetValue.copyLink,
        ShareTargetValue.openOnComputer,
        ShareTargetValue.saveImage,
        ShareTargetValue.more,
      ]) {
        final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: _target(target), matching: find.byType(Text)),
        );
        expect(paragraph.textScaler.scale(12), lessThanOrEqualTo(36.01));
        _expectWholeWords(paragraph, reason: '$target / bold=${accessibilityCase.boldText}');
      }
      expect(find.bySemanticsLabel(l10n.coreShareOpenOnComputer), findsOneWidget);
      semantics.dispose();
    });
  }

  testWidgets('open-on-computer label remains whole with unbounded width at 3x', (tester) async {
    await _loadShareTargetFonts(tester);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    _mockChannels(tester);
    final _Fake fake = _Fake(await _writeCards(tester))..pendingRender = Completer<File>().future;
    await _openSheet(
      tester,
      fake.services,
      textScale: 3,
      content: ShareCardContent(imageUrl: '', link: _link, brandName: 'Prism', computerLink: Uri.parse(_link)),
    );
    final LayoutBuilder builder = tester.widget<LayoutBuilder>(
      find.descendant(of: _target(ShareTargetValue.openOnComputer), matching: find.byType(LayoutBuilder)),
    );
    await _closeSheet(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: UnconstrainedBox(child: builder),
          ),
        ),
      ),
    );
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(find.text('Open on computer'));
    expect(paragraph.constraints.maxWidth, double.infinity);
    expect(paragraph.textScaler.scale(12), 36);
    _expectWholeWords(paragraph, reason: 'unbounded 3x Open on computer');
    expect(tester.takeException(), isNull);
    expect(
      paragraph
          .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length))
          .map((TextBox box) => box.top)
          .toSet(),
      hasLength(1),
    );
  });
}

Finder _formatSemantics(String label) =>
    find.byWidgetPredicate((Widget widget) => widget is Semantics && widget.properties.label == label);

/// A point on the card that peeks in from the right. The format label sits off screen.
Offset _rightFormatPeek(WidgetTester tester) {
  final Rect pages = tester.getRect(_pages());
  return Offset(pages.right - 4, pages.top + pages.height * 0.35);
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(5, 5));
  await _settle(tester);
}
