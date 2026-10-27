import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpOverlay(WidgetTester tester, {String? spatialMapUrl, bool reduceMotion = false}) async {
  await tester.pumpWidget(
    MaterialApp(
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
}
