import 'package:Prism/features/palette/views/widgets/clock_overlay.dart';
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
              builder: (_) => const ClockOverlay(link: 'missing.png', file: true, accent: null, colorChanged: false),
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
}
