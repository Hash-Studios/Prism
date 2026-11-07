import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:Prism/features/share_in/domain/shared_item.dart';
import 'package:Prism/features/share_in/views/widgets/share_in_sheet.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

/// A 1 x 1 PNG. The read seam is faked, so the bytes only need to decode.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

final Uri _page = Uri.parse('https://example.com/p');
const SharedImage _image = SharedImage('/tmp/x.png');
const String _imagePath = '/tmp/x.png';

/// What the test host saw: the sheet's pop, the fakes' calls and the photo the read seam returns.
class _Probe {
  final FakeAppAnalytics analytics = FakeAppAnalytics();
  bool done = false;
  ShareInChoice? choice;
  int signInCalls = 0;
  bool signInResult = true;
  final List<String> readPaths = <String>[];
  final List<String> pathChanges = <String>[];
  final List<String> discardedPaths = <String>[];
  bool readThrows = false;
  PhotoSize photo = const PhotoSize(1000, 1000);
}

void _phoneView(WidgetTester tester, {Size physical = const Size(1080, 2340), double dpr = 3}) {
  tester.view.physicalSize = physical;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester, {
  required SharedItem? item,
  required _Probe probe,
  Future<String?> Function(Uri page)? findLinkImage,
  bool isGuest = false,
  bool isPro = false,
  double textScale = 1,
  ThemeData? theme,
}) async {
  AnalyticsRuntime.instance = probe.analytics;
  addTearDown(AnalyticsRuntime.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? kLightTheme,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => unawaited(
                showPrismSheet<ShareInChoice>(
                  context,
                  builder: (_) => ShareInSheet(
                    item: item,
                    findLinkImage: findLinkImage ?? (Uri page) async => null,
                    onPathChanged: probe.pathChanges.add,
                    discardPath: (String path) async => probe.discardedPaths.add(path),
                    readPhoto: (String path) async {
                      probe.readPaths.add(path);
                      if (probe.readThrows) throw const FileSystemException('The file is gone.');
                      return PhotoSource(bytes: _png, size: probe.photo);
                    },
                    signIn: (BuildContext _) async {
                      probe.signInCalls++;
                      return probe.signInResult;
                    },
                    isGuest: isGuest,
                    isPro: isPro,
                    screenSize: const PhotoSize(1080, 2340),
                  ),
                ).then((ShareInChoice? choice) {
                  probe.choice = choice;
                  probe.done = true;
                }),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Scrolls the sheet body until [title] is on screen. The sheet body is a scroll view at large text.
Future<void> _reveal(WidgetTester tester, String title) async {
  final Finder list = find.descendant(of: find.byType(PrismSheetBody), matching: find.byType(Scrollable));
  if (list.evaluate().isEmpty) return;
  await tester.scrollUntilVisible(find.text(title), 100, scrollable: list.first);
  await tester.pump();
}

void main() {
  group('image sheet', () {
    testWidgets('shows the title, the three rows and the Fit coin cost for a photo that needs Extend', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe();
      await _pump(tester, item: _image, probe: probe);

      expect(find.text('Use this image'), findsOneWidget);
      expect(find.text('Set as wallpaper'), findsOneWidget);
      expect(find.text('Upload to Prism'), findsOneWidget);
      final int cost = photoJobCost(PhotoJobMode.extend, isPro: false);
      expect(find.text('Make it fit · $cost ${cost == 1 ? 'coin' : 'coins'}'), findsOneWidget);
    });

    testWidgets('a photo that already fits shows Already fits and tapping Make it fit keeps the sheet open', (
      tester,
    ) async {
      _phoneView(tester);
      final _Probe probe = _Probe()..photo = const PhotoSize(1080, 2340);
      await _pump(tester, item: _image, probe: probe);

      expect(find.text('Make it fit'), findsOneWidget);
      expect(find.text('Already fits your screen'), findsOneWidget);

      await _tap(tester, 'Make it fit');

      expect(probe.done, isFalse);
      expect(find.text('Use this image'), findsOneWidget);
    });

    testWidgets('signed-in Set as wallpaper pops set with the path and no photo', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe();
      await _pump(tester, item: _image, probe: probe);

      await _tap(tester, 'Set as wallpaper');

      expect(probe.done, isTrue);
      expect(probe.choice?.action, ShareInAction.set);
      expect(probe.choice?.path, _imagePath);
      expect(probe.choice?.photo, isNull);
    });

    testWidgets('signed-in Make it fit pops fit with the path and the photo', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe();
      await _pump(tester, item: _image, probe: probe);

      final int cost = photoJobCost(PhotoJobMode.extend, isPro: false);
      await _tap(tester, 'Make it fit · $cost ${cost == 1 ? 'coin' : 'coins'}');

      expect(probe.done, isTrue);
      expect(probe.choice?.action, ShareInAction.fit);
      expect(probe.choice?.path, _imagePath);
      expect(probe.choice?.photo, isNotNull);
      expect(probe.choice?.photo?.size, const PhotoSize(1000, 1000));
    });

    testWidgets('signed-in Upload to Prism pops upload', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe();
      await _pump(tester, item: _image, probe: probe);

      await _tap(tester, 'Upload to Prism');

      expect(probe.done, isTrue);
      expect(probe.choice?.action, ShareInAction.upload);
      expect(probe.choice?.path, _imagePath);
      expect(probe.choice?.photo, isNull);
    });

    testWidgets('guest sees the sign-in note on Fit and Upload', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe();
      await _pump(tester, item: _image, probe: probe, isGuest: true);

      expect(find.text('Sign in to use this.'), findsNWidgets(2));
    });

    testWidgets('guest Set as wallpaper pops set and never asks to sign in', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe();
      await _pump(tester, item: _image, probe: probe, isGuest: true);

      await _tap(tester, 'Set as wallpaper');

      expect(probe.choice?.action, ShareInAction.set);
      expect(probe.signInCalls, 0);
    });

    testWidgets('guest Upload that is not signed in keeps the sheet open and pops nothing', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe()..signInResult = false;
      await _pump(tester, item: _image, probe: probe, isGuest: true);

      await _tap(tester, 'Upload to Prism');

      expect(probe.signInCalls, 1);
      expect(probe.done, isFalse);
      expect(find.text('Use this image'), findsOneWidget);
    });

    testWidgets('guest Upload that signs in pops upload', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe()..signInResult = true;
      await _pump(tester, item: _image, probe: probe, isGuest: true);

      await _tap(tester, 'Upload to Prism');

      expect(probe.signInCalls, 1);
      expect(probe.choice?.action, ShareInAction.upload);
    });

    testWidgets('the preview has the Shared image semantics label', (tester) async {
      _phoneView(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Probe probe = _Probe();
      await _pump(tester, item: _image, probe: probe);

      expect(find.bySemanticsLabel('Shared image'), findsOneWidget);
      handle.dispose();
    });
  });

  group('link sheet', () {
    testWidgets('guest can Set the image downloaded from a link without sign-in', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe()..signInResult = false;
      await _pump(
        tester,
        item: SharedUrl(_page),
        probe: probe,
        isGuest: true,
        findLinkImage: (_) async => '/tmp/link.png',
      );

      await _tap(tester, 'Set as wallpaper');

      expect(probe.signInCalls, 0);
      expect(probe.choice?.action, ShareInAction.set);
      expect(probe.choice?.path, '/tmp/link.png');
    });

    testWidgets('an image found after the sheet closes is discarded without reading it', (tester) async {
      _phoneView(tester);
      final Completer<String?> found = Completer<String?>();
      final _Probe probe = _Probe();
      await _pump(tester, item: SharedUrl(_page), probe: probe, findLinkImage: (_) => found.future);
      await tester.pumpWidget(const SizedBox());

      found.complete('/tmp/late.png');
      await tester.pump();

      expect(probe.discardedPaths, <String>['/tmp/late.png']);
      expect(probe.pathChanges, isEmpty);
      expect(probe.readPaths, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a thrown link lookup shows the failed state', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe();
      await _pump(
        tester,
        item: SharedUrl(_page),
        probe: probe,
        findLinkImage: (_) async => throw StateError('lookup unavailable'),
      );

      expect(find.text('Prism cannot use this link.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('shows the finding state until the image is found, then the three actions', (tester) async {
      _phoneView(tester);
      final Completer<String?> found = Completer<String?>();
      final _Probe probe = _Probe();
      await _pump(tester, item: SharedUrl(_page), probe: probe, findLinkImage: (_) => found.future);

      expect(find.text('Finding the image in this link'), findsOneWidget);
      expect(find.text('Set as wallpaper'), findsNothing);

      found.complete('/tmp/y.png');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Finding the image in this link'), findsNothing);
      expect(find.text('Set as wallpaper'), findsOneWidget);
      expect(find.text('Upload to Prism'), findsOneWidget);
      expect(probe.pathChanges, <String>['/tmp/y.png']);
      expect(probe.readPaths, <String>['/tmp/y.png']);
    });

    testWidgets('no image in the link shows the link failed state and a failed analytics event', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe();
      await _pump(tester, item: SharedUrl(_page), probe: probe, findLinkImage: (_) async => null);

      expect(find.text('Prism cannot use this link.'), findsOneWidget);
      expect(find.text('Share an image, or a link to a page with an image.'), findsOneWidget);
      expect(probe.pathChanges, isEmpty);
      final List<ShareActionEvent> events = probe.analytics.events.whereType<ShareActionEvent>().toList();
      expect(events.map((ShareActionEvent e) => e.action), <ShareActionValue>[ShareActionValue.failed]);
    });

    testWidgets('no item shows the link failed state', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe();
      await _pump(tester, item: null, probe: probe);

      expect(find.text('Prism cannot use this link.'), findsOneWidget);
      expect(find.text('Share an image, or a link to a page with an image.'), findsOneWidget);
    });

    testWidgets('an image that cannot be read shows the image failed state', (tester) async {
      _phoneView(tester);
      final _Probe probe = _Probe()..readThrows = true;
      await _pump(tester, item: _image, probe: probe);

      expect(find.text('Prism cannot open this image.'), findsOneWidget);
      expect(find.text('Share it again, or share a different image.'), findsOneWidget);
    });
  });

  group('large text and themes', () {
    testWidgets('the image sheet renders at 2x text on a phone with every row reachable', (tester) async {
      _phoneView(tester, physical: const Size(1170, 2532));
      final _Probe probe = _Probe();
      await _pump(tester, item: _image, probe: probe, textScale: 2);

      expect(tester.takeException(), isNull);
      for (final String title in <String>['Set as wallpaper', 'Upload to Prism']) {
        await _reveal(tester, title);
        expect(find.text(title), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the failed link sheet renders at 2x text with no exception', (tester) async {
      _phoneView(tester, physical: const Size(1170, 2532));
      final _Probe probe = _Probe();
      await _pump(tester, item: SharedUrl(_page), probe: probe, findLinkImage: (_) async => null, textScale: 2);

      expect(tester.takeException(), isNull);
      await _reveal(tester, 'Prism cannot use this link.');
      expect(find.text('Prism cannot use this link.'), findsOneWidget);
    });

    for (final (String name, ThemeData theme) in <(String, ThemeData)>[('light', kLightTheme), ('dark', kDarkTheme)]) {
      testWidgets('the image sheet pumps in the $name theme with no exception', (tester) async {
        _phoneView(tester);
        final _Probe probe = _Probe();
        await _pump(tester, item: _image, probe: probe, theme: theme);

        expect(tester.takeException(), isNull);
        expect(find.text('Set as wallpaper'), findsOneWidget);
      });
    }
  });
}
