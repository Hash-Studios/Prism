import 'dart:io';

import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openPreview(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ClockOverlay(link: File('assets/images/prism.webp').path, file: true, accent: null),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

bool _isDockIcon(Widget widget) =>
    widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName.contains('playstore');

void main() {
  test('ordinal suffix uses th for 11 to 13', () {
    expect(<int>[1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31].map(ClockOverlay.ordinalSuffix).toList(), <String>[
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
      'ˢᵗ',
    ]);
  });

  testWidgets('iOS previews a lock screen without the Android dock', (WidgetTester tester) async {
    await _openPreview(tester);

    expect(find.byWidgetPredicate(_isDockIcon), findsNothing);
    expect(find.textContaining('27°C'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android keeps the launcher preview', (WidgetTester tester) async {
    await _openPreview(tester);

    expect(find.byWidgetPredicate(_isDockIcon), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the preview closes from a labelled button', (WidgetTester tester) async {
    await _openPreview(tester);

    await tester.tap(find.bySemanticsLabel('Close preview'));
    await tester.pumpAndSettle();

    expect(find.byType(ClockOverlay), findsNothing);
  });

  testWidgets('the preview never tints the image, even with a user-selected accent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClockOverlay(link: File('assets/images/prism.webp').path, file: true, accent: Colors.red),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.color, isNull);
    expect(image.colorBlendMode, isNull);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  test('the time follows the 12 or 24 hour setting', () {
    final afternoon = DateTime(2026, 1, 5, 15, 7);

    expect(ClockOverlay.formatTime(afternoon, use24Hour: false), '3:07');
    expect(ClockOverlay.formatTime(afternoon, use24Hour: true), '15:07');
  });

  testWidgets('the Android lock view shows the device time style and no dock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: ClockOverlay(link: File('assets/images/prism.webp').path, file: true, accent: null),
        ),
      ),
    );

    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate(_isDockIcon), findsNothing);
    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the Home toggle hides the big clock on iOS', (tester) async {
    await _openPreview(tester);
    expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
