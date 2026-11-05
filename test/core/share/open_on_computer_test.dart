import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/share/open_on_computer.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';

import '../../support/fake_app_analytics.dart';

const String _link = 'https://prismwalls.com/l/Ab3dEf7h?d=1';
const String _display = 'prismwalls.com/l/Ab3dEf7h?d=1';
const String _fallback = 'https://prismwalls.com/wallpaper/WBN0?view=desktop';
const MethodChannel _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

Future<void> _noopCopy(String text) async {}

/// Toasts and haptics go to platform channels, so answer them here.
void _mockChannels(WidgetTester tester, {List<MethodCall>? toastCalls}) {
  final TestDefaultBinaryMessenger messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_toastChannel, (MethodCall call) async {
    toastCalls?.add(call);
    return true;
  });
  messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() {
    messenger.setMockMethodCallHandler(_toastChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

/// Opens the sheet the way the app does: showOpenOnComputerSheet hosts it in a prism sheet route.
/// Pumping OpenOnComputerSheet on its own throws a null check inside the sheet body.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required Future<void> Function(String text) copyText,
  ThemeData? theme,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? prismLightThemes.first.theme,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showOpenOnComputerSheet(
                context,
                link: Uri.parse(_link),
                sourceContext: 'wallpaper_screen',
                copyText: copyText,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    AnalyticsRuntime.reset();
  });
  tearDown(() {
    AnalyticsRuntime.reset();
  });

  group('openOnComputerLink', () {
    test('a short link gets the desktop hint', () {
      final Uri? link = openOnComputerLink(wallId: 'WBN0', shareLink: 'https://prismwalls.com/l/Ab3dEf7h');
      expect(link.toString(), _link);
    });

    test('a long canonical fallback link becomes the wall page in desktop mode', () {
      final Uri? link = openOnComputerLink(
        wallId: 'WBN0',
        shareLink: 'https://prismwalls.com/share?id=WBN0&source=prism&provider=Prism&thumb=',
      );
      expect(link.toString(), _fallback);
    });

    test('a link on another host or an http scheme falls back to the wall page', () {
      expect(openOnComputerLink(wallId: 'WBN0', shareLink: 'https://evil.example/l/Ab3dEf7h').toString(), _fallback);
      expect(openOnComputerLink(wallId: 'WBN0', shareLink: 'http://prismwalls.com/l/Ab3dEf7h').toString(), _fallback);
    });

    test('bad wall ids return null', () {
      for (final String wallId in <String>['', 'a/b', '../x']) {
        expect(
          openOnComputerLink(wallId: wallId, shareLink: 'https://prismwalls.com/l/Ab3dEf7h'),
          isNull,
          reason: 'wall id "$wallId" must be rejected',
        );
      }
    });

    test('the display string has no scheme and keeps the query', () {
      expect(openOnComputerDisplay(Uri.parse(_link)), _display);
    });
  });

  group('OpenOnComputerSheet', () {
    testWidgets('shows the title, the link as typed, the QR tile, and tracks the open', (tester) async {
      _mockChannels(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      addTearDown(AnalyticsRuntime.reset);

      await _pumpSheet(tester, copyText: _noopCopy);
      await tester.pump();

      expect(find.text('Open on computer'), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey<String>('open-on-computer-link'))).data, _display);
      expect(find.bySemanticsLabel('QR code for $_display'), findsOneWidget);
      final List<OpenOnComputerShownEvent> shown = analytics.events.whereType<OpenOnComputerShownEvent>().toList();
      expect(shown, hasLength(1));
      expect(shown.single.sourceContext, 'wallpaper_screen');
      semantics.dispose();
    });

    testWidgets('copy sends the exact link and tracks success', (tester) async {
      _mockChannels(tester);
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      addTearDown(AnalyticsRuntime.reset);
      final List<String> copied = <String>[];

      await _pumpSheet(tester, copyText: (String text) async => copied.add(text));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('open-on-computer-copy')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(copied, <String>[_link]);
      final List<OpenOnComputerLinkCopiedEvent> copies = analytics.events
          .whereType<OpenOnComputerLinkCopiedEvent>()
          .toList();
      expect(copies, hasLength(1));
      expect(copies.single.result, EventResultValue.success);
      expect(copies.single.sourceContext, 'wallpaper_screen');
    });

    testWidgets('a failed copy tracks failure and does not throw', (tester) async {
      final List<MethodCall> toastCalls = <MethodCall>[];
      _mockChannels(tester, toastCalls: toastCalls);
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      addTearDown(AnalyticsRuntime.reset);

      await _pumpSheet(tester, copyText: (String text) async => throw PlatformException(code: 'clipboard_failed'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('open-on-computer-copy')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      final List<OpenOnComputerLinkCopiedEvent> copies = analytics.events
          .whereType<OpenOnComputerLinkCopiedEvent>()
          .toList();
      expect(copies, hasLength(1));
      expect(copies.single.result, EventResultValue.failure);
      expect(toastCalls, isNotEmpty);
    });

    for (final double scale in <double>[2.0, 3.0]) {
      testWidgets('large text at $scale x does not overflow and copy still works', (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        _mockChannels(tester);
        final List<String> copied = <String>[];

        await _pumpSheet(tester, copyText: (String text) async => copied.add(text), textScale: scale);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          tester.widget<SelectableText>(find.byKey(const ValueKey<String>('open-on-computer-link'))).data,
          _display,
        );

        final Finder copy = find.byKey(const ValueKey<String>('open-on-computer-copy'));
        await tester.ensureVisible(copy);
        await tester.pump();
        await tester.tap(copy);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(copied, <String>[_link]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('dark mode keeps the QR tile white and paints the link as scannable modules', (tester) async {
      _mockChannels(tester);
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      addTearDown(AnalyticsRuntime.reset);
      final Finder qr = find.byKey(const ValueKey<String>('open-on-computer-qr'));

      await _pumpSheet(tester, copyText: _noopCopy, theme: prismDarkThemes.first.theme);
      await tester.pump();

      final Container tile = tester.widget<Container>(find.descendant(of: qr, matching: find.byType(Container)));
      expect((tile.decoration! as BoxDecoration).color, const Color(0xFFFFFFFF));

      // Paint only the tile, on the dark theme, and read the pixels back. Unmount the sheet first so its route
      // does not rebuild without localizations.
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: prismDarkThemes.first.theme,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: const SizedBox(
                width: 264,
                height: 264,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: QrTile(key: ValueKey<String>('open-on-computer-qr'), data: _link),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final QrImage image = QrImage(QrCode(payload: QrPayload.fromString(_link)));
      final int modules = image.moduleCount;
      expect(modules, greaterThanOrEqualTo(21));
      expect(tester.getSize(find.byKey(const ValueKey<String>('open-on-computer-qr'))), const Size(260, 260));

      final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      final ({int width, Uint8List pixels})? captured = await tester.runAsync(() async {
        final ui.Image img = await boundary.toImage();
        final ByteData? bytes = await img.toByteData();
        return (width: img.width, pixels: bytes!.buffer.asUint8List());
      });
      expect(captured, isNotNull);
      final int width = captured!.width;
      expect(width, 264);

      const int quietZone = 4;
      final int cells = modules + quietZone * 2;
      const double side = 260;
      final double cell = side / cells;
      List<int> pixelAt(double x, double y) {
        final int offset = (y.floor() * width + x.floor()) * 4;
        return captured.pixels.sublist(offset, offset + 3);
      }

      for (int row = 0; row < modules; row++) {
        for (int col = 0; col < modules; col++) {
          final List<int> rgb = pixelAt((col + quietZone + 0.5) * cell, (row + quietZone + 0.5) * cell);
          if (image.isDark(row, col)) {
            expect(rgb, everyElement(lessThan(40)), reason: 'module ($row, $col) must be black');
          } else {
            expect(rgb, everyElement(greaterThan(215)), reason: 'module ($row, $col) must be white');
          }
        }
      }

      // One cell in from each corner of the quiet zone. The tile has 16 px rounded corners,
      // so the very corner pixel is outside the tile and is not sampled.
      final double near = 1.5 * cell;
      final double far = (cells - 1.5) * cell;
      for (final (double x, double y) in <(double, double)>[(near, near), (far, near), (near, far), (far, far)]) {
        expect(pixelAt(x, y), everyElement(greaterThan(215)), reason: 'quiet zone at ($x, $y) must be white');
      }
    });
  });
}
