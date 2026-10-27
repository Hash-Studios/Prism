import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  Size size = const Size(400, 800),
  double statusBar = 0,
  double navigationBar = 0,
  bool alwaysUse24HourFormat = true,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      padding: EdgeInsets.only(top: statusBar, bottom: navigationBar),
      viewPadding: EdgeInsets.only(top: statusBar, bottom: navigationBar),
      alwaysUse24HourFormat: alwaysUse24HourFormat,
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
  final ColorScheme teal = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark);
  const List<Size> frames = <Size>[Size(400, 800), Size(100, 200)];

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

  double left(WidgetTester tester, Finder finder, Type layer) =>
      tester.getTopLeft(finder).dx - tester.getTopLeft(find.byType(layer)).dx;

  double bottom(WidgetTester tester, Finder finder, Type layer) =>
      tester.getBottomLeft(finder).dy - tester.getTopLeft(find.byType(layer)).dy;

  Finder dockIcons() => find.descendant(of: find.byKey(previewDockKey), matching: find.byType(Icon));

  Finder homeIcons() => find.descendant(of: find.byType(HomePreviewLayer), matching: find.byType(Icon));

  bool hasShapeColor(WidgetTester tester, Finder icon, Color color) =>
      tester.widgetList<DecoratedBox>(find.ancestor(of: icon, matching: find.byType(DecoratedBox))).any((box) {
        final Decoration decoration = box.decoration;
        return decoration is ShapeDecoration && decoration.color == color;
      });

  testWidgets('the Android lock layer shows the time and date in the given colour', (tester) async {
    await tester.pumpWidget(_host(LockPreviewLayer(textColor: Colors.white, now: now)));

    final Text time = tester.widget<Text>(find.text('15:07'));
    expect(time.style?.color, Colors.white);
    expect(find.text('Wednesday, March 4'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the iOS lock layer shows the date above a large time', (tester) async {
    await tester.pumpWidget(_host(LockPreviewLayer(textColor: Colors.black, now: now)));

    expect(find.text('Wednesday, March 4'), findsOneWidget);
    expect(tester.widget<Text>(find.text('15:07')).style?.fontSize, 96);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the Android home layer shows the date and five dock icons', (tester) async {
    await tester.pumpWidget(_host(HomePreviewLayer(textColor: Colors.white, now: now)));

    expect(find.text('Wed, Mar 4'), findsOneWidget);
    expect(dockIcons(), findsNWidgets(5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the iOS home layer draws the weekday, the day, 12 grid icons and the dock', (tester) async {
    await tester.pumpWidget(_host(HomePreviewLayer(textColor: Colors.white, now: now)));

    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(homeIcons(), findsNWidgets(16));
    expect(dockIcons(), findsNWidgets(4));
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

      expect(top(tester, find.text('Wednesday, March 4'), LockPreviewLayer), 64);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the iOS lock date starts 24 from the top when there is no status bar', (tester) async {
      await pumpOnPhoneScreen(tester, LockPreviewLayer(textColor: Colors.white, now: now));

      expect(top(tester, find.text('Wednesday, March 4'), LockPreviewLayer), 24);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the Android lock block is centred in the top third below the status bar', (tester) async {
      await pumpOnPhoneScreen(tester, LockPreviewLayer(textColor: Colors.white, now: now), statusBar: 40);

      final double blockTop = top(tester, find.text('15:07'), LockPreviewLayer);
      final double blockBottom = bottom(tester, find.text('Wednesday, March 4'), LockPreviewLayer);
      expect((blockTop + blockBottom) / 2, closeTo(40 + (800 - 40) / 6, 0.01));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the Android home date starts 24 from the left and 64 below the top with a status bar of 40', (
      tester,
    ) async {
      await pumpOnPhoneScreen(tester, HomePreviewLayer(textColor: Colors.white, now: now), statusBar: 40);

      expect(top(tester, find.text('Wed, Mar 4'), HomePreviewLayer), 64);
      expect(left(tester, find.text('Wed, Mar 4'), HomePreviewLayer), 24);
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

      expect(top(tester, find.text('Wednesday, March 4'), LockPreviewLayer), 20 + 12);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a layer in a half-size frame scales the Android date offset with the frame', (tester) async {
      await pumpOnPhoneScreen(
        tester,
        HomePreviewLayer(textColor: Colors.white, now: now),
        frame: const Size(200, 400),
        statusBar: 40,
      );

      expect(top(tester, find.text('Wed, Mar 4'), HomePreviewLayer), 32);
      expect(left(tester, find.text('Wed, Mar 4'), HomePreviewLayer), 12);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('dock', () {
    double gapBelowDock(WidgetTester tester) =>
        tester.getBottomLeft(find.byType(HomePreviewLayer)).dy - tester.getBottomLeft(find.byKey(previewDockKey)).dy;

    testWidgets('the Android dock sits 126 above the navigation bar', (tester) async {
      await pumpOnPhoneScreen(tester, HomePreviewLayer(textColor: Colors.white, now: now), navigationBar: 34);

      expect(gapBelowDock(tester), 126);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a layer in a half-size frame scales the dock offset with the frame', (tester) async {
      await pumpOnPhoneScreen(
        tester,
        HomePreviewLayer(textColor: Colors.white, now: now),
        frame: const Size(200, 400),
        navigationBar: 34,
      );

      expect(gapBelowDock(tester), 63);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('icon styles', () {
    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android]) {
      final int expectedIcons = platform == TargetPlatform.iOS ? 16 : 17;
      for (final PreviewIconStyle style in PreviewIconStyle.forPlatform(platform)) {
        for (final Size frame in frames) {
          testWidgets(
            'the ${platform.name} home draws ${style.name} icons in a ${frame.width.toInt()}x${frame.height.toInt()} frame',
            (tester) async {
              await pumpOnPhoneScreen(
                tester,
                HomePreviewLayer(textColor: Colors.white, now: now, iconStyle: style, scheme: teal),
                frame: frame,
              );

              expect(tester.takeException(), isNull);
              expect(homeIcons(), findsNWidgets(expectedIcons));
              if (style == PreviewIconStyle.clear) expect(find.byType(BackdropFilter), findsWidgets);
            },
            variant: TargetPlatformVariant.only(platform),
          );
        }
      }
    }

    testWidgets('the iOS tinted dock icons use the scheme primary colour', (tester) async {
      await pumpOnPhoneScreen(
        tester,
        HomePreviewLayer(textColor: Colors.white, now: now, iconStyle: PreviewIconStyle.tinted, scheme: teal),
      );

      expect(tester.widget<Icon>(dockIcons().first).color, teal.primary);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the iOS standard dock icons have white glyphs', (tester) async {
      await pumpOnPhoneScreen(tester, HomePreviewLayer(textColor: Colors.white, now: now, scheme: teal));

      expect(tester.widget<Icon>(dockIcons().first).color, Colors.white);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the iOS dark dock icons fill with 1C1C1E', (tester) async {
      await pumpOnPhoneScreen(
        tester,
        HomePreviewLayer(textColor: Colors.white, now: now, iconStyle: PreviewIconStyle.dark, scheme: teal),
      );

      expect(hasShapeColor(tester, dockIcons().first, const Color(0xFF1C1C1E)), isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the Android themed dock icons use the container colours of the scheme', (tester) async {
      await pumpOnPhoneScreen(
        tester,
        HomePreviewLayer(textColor: Colors.white, now: now, iconStyle: PreviewIconStyle.themed, scheme: teal),
      );

      expect(tester.widget<Icon>(dockIcons().first).color, teal.primaryContainer);
      expect(hasShapeColor(tester, dockIcons().first, teal.onPrimaryContainer), isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the Android themed icons without a scheme use a neutral grey, not the teal scheme', (tester) async {
      await pumpOnPhoneScreen(
        tester,
        HomePreviewLayer(textColor: Colors.white, now: now, iconStyle: PreviewIconStyle.themed),
      );

      expect(tester.takeException(), isNull);
      expect(tester.widget<Icon>(dockIcons().first).color, isNot(teal.primaryContainer));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('iOS lock screen', () {
    for (final Size frame in frames) {
      testWidgets(
        'draws the lock widgets and the flashlight and camera buttons in a ${frame.width.toInt()}x${frame.height.toInt()} frame',
        (tester) async {
          await pumpOnPhoneScreen(
            tester,
            LockPreviewLayer(textColor: Colors.white, now: now),
            frame: frame,
          );

          expect(tester.takeException(), isNull);
          expect(find.byIcon(Icons.flashlight_on_rounded), findsOneWidget);
          expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
          for (final IconData icon in const <IconData>[
            Icons.wb_sunny_rounded,
            Icons.directions_walk_rounded,
            Icons.battery_full_rounded,
          ]) {
            expect(find.byIcon(icon), findsOneWidget);
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  });

  testWidgets('the lock layer displays time in the device hour setting', (tester) async {
    await tester.pumpWidget(_host(LockPreviewLayer(textColor: Colors.white, now: now), alwaysUse24HourFormat: false));
    expect(find.text('3:07'), findsOneWidget);

    await tester.pumpWidget(_host(LockPreviewLayer(textColor: Colors.white, now: now)));
    expect(find.text('15:07'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
