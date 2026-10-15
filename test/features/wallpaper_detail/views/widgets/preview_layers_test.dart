import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Size size = const Size(400, 800), double statusBar = 0, double navigationBar = 0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          padding: EdgeInsets.only(top: statusBar, bottom: navigationBar),
          viewPadding: EdgeInsets.only(top: statusBar, bottom: navigationBar),
          alwaysUse24HourFormat: true,
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: size.width, height: size.height, child: child),
          ),
        ),
      ),
    );

void main() {
  final DateTime now = DateTime(2026, 3, 4, 15, 7);

  Future<void> pumpOnPhoneScreen(
    WidgetTester tester,
    Widget layer, {
    Size frame = const Size(400, 800),
    double statusBar = 0,
    double navigationBar = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(layer, size: frame, statusBar: statusBar, navigationBar: navigationBar));
  }

  double top(WidgetTester tester, Finder finder, Type layer) =>
      tester.getTopLeft(finder).dy - tester.getTopLeft(find.byType(layer)).dy;

  double bottom(WidgetTester tester, Finder finder, Type layer) =>
      tester.getBottomLeft(finder).dy - tester.getTopLeft(find.byType(layer)).dy;

  testWidgets('the Android lock layer shows the time and date in the given colour', (tester) async {
    await tester.pumpWidget(_host(LockPreviewLayer(textColor: Colors.white, now: now)));

    final Text time = tester.widget<Text>(find.text('15:07'));
    expect(time.style?.color, Colors.white);
    expect(find.text('Wednesday, March 4'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the iOS lock layer shows the date above a large time', (tester) async {
    await tester.pumpWidget(_host(LockPreviewLayer(textColor: Colors.black, now: now)));

    expect(find.text('Wednesday 4 March'), findsOneWidget);
    expect(tester.widget<Text>(find.text('15:07')).style?.fontSize, 96);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the Android home layer shows the date and five dock icons', (tester) async {
    await tester.pumpWidget(_host(HomePreviewLayer(textColor: Colors.white, now: now)));

    expect(find.text('Wednesday,'), findsOneWidget);
    expect(find.text('March 4ᵗʰ'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the iOS home layer draws nothing', (tester) async {
    await tester.pumpWidget(_host(HomePreviewLayer(textColor: Colors.white, now: now)));

    expect(find.byType(Text), findsNothing);
    expect(find.byType(Image), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a layer in a smaller frame scales its text down', (tester) async {
    await tester.pumpWidget(
      _host(
        LockPreviewLayer(textColor: Colors.white, now: now),
        size: const Size(200, 400),
      ),
    );

    expect(tester.widget<Text>(find.text('15:07')).style?.fontSize, 36);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  group('status bar', () {
    testWidgets('the iOS lock date starts 24 below the status bar', (tester) async {
      await pumpOnPhoneScreen(tester, LockPreviewLayer(textColor: Colors.white, now: now), statusBar: 40);

      expect(top(tester, find.text('Wednesday 4 March'), LockPreviewLayer), 64);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the iOS lock date starts 24 from the top when there is no status bar', (tester) async {
      await pumpOnPhoneScreen(tester, LockPreviewLayer(textColor: Colors.white, now: now));

      expect(top(tester, find.text('Wednesday 4 March'), LockPreviewLayer), 24);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the Android lock block is centred in the top third below the status bar', (tester) async {
      await pumpOnPhoneScreen(tester, LockPreviewLayer(textColor: Colors.white, now: now), statusBar: 40);

      final double blockTop = top(tester, find.text('15:07'), LockPreviewLayer);
      final double blockBottom = bottom(tester, find.text('Wednesday, March 4'), LockPreviewLayer);
      expect((blockTop + blockBottom) / 2, closeTo(40 + (800 - 40) / 6, 0.01));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the Android home block is centred in the top third below the status bar', (tester) async {
      await pumpOnPhoneScreen(tester, HomePreviewLayer(textColor: Colors.white, now: now), statusBar: 40);

      final double blockTop = top(tester, find.text('Wednesday,'), HomePreviewLayer);
      final double blockBottom = bottom(tester, find.text('March 4ᵗʰ'), HomePreviewLayer);
      expect((blockTop + blockBottom) / 2, closeTo(40 + (800 - 40) / 6, 0.01));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the Android blocks are centred in the top third of the whole frame when there is no status bar', (
      tester,
    ) async {
      await pumpOnPhoneScreen(tester, LockPreviewLayer(textColor: Colors.white, now: now));

      final double blockTop = top(tester, find.text('15:07'), LockPreviewLayer);
      final double blockBottom = bottom(tester, find.text('Wednesday, March 4'), LockPreviewLayer);
      expect((blockTop + blockBottom) / 2, closeTo(800 / 6, 0.01));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a layer in a half-size frame scales the iOS offset with the frame', (tester) async {
      await pumpOnPhoneScreen(
        tester,
        LockPreviewLayer(textColor: Colors.white, now: now),
        frame: const Size(200, 400),
        statusBar: 40,
      );

      expect(top(tester, find.text('Wednesday 4 March'), LockPreviewLayer), 20 + 12);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a layer in a half-size frame scales the Android offset with the frame', (tester) async {
      await pumpOnPhoneScreen(
        tester,
        HomePreviewLayer(textColor: Colors.white, now: now),
        frame: const Size(200, 400),
        statusBar: 40,
      );

      final double blockTop = top(tester, find.text('Wednesday,'), HomePreviewLayer);
      final double blockBottom = bottom(tester, find.text('March 4ᵗʰ'), HomePreviewLayer);
      expect((blockTop + blockBottom) / 2, closeTo(20 + (400 - 20) / 6, 0.01));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('dock', () {
    double gapBelowDock(WidgetTester tester) {
      final Finder dock = find.descendant(of: find.byType(HomePreviewLayer), matching: find.byType(Row));
      return tester.getBottomLeft(find.byType(HomePreviewLayer)).dy - tester.getBottomLeft(dock).dy;
    }

    testWidgets('the Android dock sits 100 above the navigation bar', (tester) async {
      await pumpOnPhoneScreen(tester, HomePreviewLayer(textColor: Colors.white, now: now), navigationBar: 34);

      expect(gapBelowDock(tester), 134);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a layer in a half-size frame scales the dock offset with the frame', (tester) async {
      await pumpOnPhoneScreen(
        tester,
        HomePreviewLayer(textColor: Colors.white, now: now),
        frame: const Size(200, 400),
        navigationBar: 34,
      );

      expect(gapBelowDock(tester), 67);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  test('ordinal suffixes and the clock follow the 12 or 24 hour setting', () {
    expect(<int>[1, 2, 3, 4, 11, 12, 13, 21, 22, 23].map(ordinalSuffix).toList(), <String>[
      'ˢᵗ',
      'ⁿᵈ',
      'ʳᵈ',
      'ᵗʰ',
      'ᵗʰ',
      'ᵗʰ',
      'ᵗʰ',
      'ˢᵗ',
      'ⁿᵈ',
      'ʳᵈ',
    ]);
    expect(formatClockTime(now, use24Hour: false), '3:07');
    expect(formatClockTime(now, use24Hour: true), '15:07');
  });
}
