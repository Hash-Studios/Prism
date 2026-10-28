import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/spatial_tilt_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpOverlay(
  WidgetTester tester, {
  String? spatialMapUrl,
  bool reduceMotion = false,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: ClockOverlay(link: 'assets/images/prism.webp', file: false, spatialMapUrl: spatialMapUrl),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the 3D toggle on iOS when a depth map is set', (tester) async {
    await _pumpOverlay(tester, spatialMapUrl: 'https://x/m.png');

    expect(find.byTooltip('Preview in 3D'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('shows the 3D toggle on Android when a depth map is set', (tester) async {
    await _pumpOverlay(tester, spatialMapUrl: 'https://x/m.png');

    expect(find.byTooltip('Preview in 3D'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('hides the 3D toggle when no depth map is set', (tester) async {
    await _pumpOverlay(tester);

    expect(find.byTooltip('Preview in 3D'), findsNothing);
    expect(find.text('3D'), findsNothing);
  });

  testWidgets('shows the 3D toggle with reduce motion on when a depth map is set', (tester) async {
    await _pumpOverlay(tester, spatialMapUrl: 'https://x/m.png', reduceMotion: true);

    expect(find.byTooltip('Preview in 3D'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
  });

  testWidgets('the 3D toggle sits next to the close button, as tall as it', (tester) async {
    await _pumpOverlay(tester, spatialMapUrl: 'https://x/m.png');

    final Finder toggle = find.ancestor(of: find.text('3D'), matching: find.byType(Tooltip)).first;
    expect(tester.getSize(toggle).height, 48);
    expect(tester.getCenter(toggle).dy, tester.getCenter(find.byTooltip('Close preview')).dy);
  });

  testWidgets('close, 3D and Save to Photos fit one row on a narrow screen at large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: ClockOverlay(
          link: 'assets/images/prism.webp',
          file: false,
          spatialMapUrl: 'https://x/m.png',
          saveAction: (label) => PrismButton(label: label, onPressed: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.text('Save to Photos')).right, lessThanOrEqualTo(320));
    expect(tester.getCenter(find.text('3D')).dy, tester.getCenter(find.byTooltip('Close preview')).dy);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('turning 3D off removes the tilt view, and closing while on returns to the caller', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const ClockOverlay(
                    link: 'assets/images/prism.webp',
                    file: false,
                    spatialMapUrl: 'https://x/m.png',
                  ),
                ),
              ),
              child: const Text('Open preview'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3D'));
    await tester.pump();
    expect(find.byType(SpatialTiltView), findsOneWidget);

    await tester.tap(find.text('3D'));
    await tester.pump();
    expect(find.byType(SpatialTiltView), findsNothing);

    await tester.tap(find.text('3D'));
    await tester.pump();
    expect(find.byType(SpatialTiltView), findsOneWidget);
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();

    expect(find.byType(ClockOverlay), findsNothing);
    expect(find.text('Open preview'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
