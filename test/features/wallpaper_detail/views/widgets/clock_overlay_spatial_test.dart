import 'package:Prism/core/widgets/prism_glass.dart';
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

  testWidgets('the selected 3D toggle uses its theme primary and on-primary colors', (tester) async {
    const Color primary = Color(0xFF123456);
    const Color onPrimary = Color(0xFFFEDCBA);
    const ColorScheme colors = ColorScheme.light(primary: primary, onPrimary: onPrimary);
    await _pumpOverlay(
      tester,
      spatialMapUrl: 'https://x/m.png',
      theme: ThemeData(colorScheme: colors),
    );

    await tester.tap(find.text('3D'));
    await tester.pump();

    void expectColors({required Color background, required Color foreground, required Color glass}) {
      final AnimatedContainer selected = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.text('3D'), matching: find.byType(AnimatedContainer)).first,
      );
      expect((selected.decoration! as BoxDecoration).color, background);
      final AnimatedDefaultTextStyle label = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(of: find.text('3D'), matching: find.byType(AnimatedDefaultTextStyle)).first,
      );
      expect(label.style.color, foreground);
      final Finder glassWidget = find.ancestor(of: find.text('3D'), matching: find.byType(PrismGlass));
      expect(tester.widget<PrismGlass>(glassWidget).glassColor, glass);
    }

    expectColors(background: primary, foreground: onPrimary, glass: colors.scrim.withValues(alpha: 0.6));
    await tester.tap(find.text('3D'));
    await tester.pump();
    expectColors(
      background: Colors.transparent,
      foreground: colors.onInverseSurface,
      glass: colors.inverseSurface,
    );
  });

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
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(ClockOverlay), findsNothing);
    expect(find.text('Open preview'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
