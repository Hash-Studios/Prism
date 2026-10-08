import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Size size = const Size(400, 800)}) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(400, 800), alwaysUse24HourFormat: true),
    child: Scaffold(
      body: Center(
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  ),
);

void main() {
  final DateTime now = DateTime(2026, 3, 4, 15, 7);

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
