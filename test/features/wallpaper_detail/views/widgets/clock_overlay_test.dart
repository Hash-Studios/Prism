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
              builder: (_) => ClockOverlay(
                link: File('assets/images/prism.webp').path,
                file: true,
                accent: null,
                colorChanged: false,
              ),
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

  testWidgets('a downloaded file is not tinted until the user changes its accent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClockOverlay(
          link: File('assets/images/prism.webp').path,
          file: true,
          accent: Colors.red,
          colorChanged: false,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.color, isNull);
    expect(image.colorBlendMode, isNull);
  });

  testWidgets('a user-selected accent tints the downloaded file preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClockOverlay(
          link: File('assets/images/prism.webp').path,
          file: true,
          accent: Colors.red,
          colorChanged: true,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.color, Colors.red);
    expect(image.colorBlendMode, BlendMode.hue);
  });
}
