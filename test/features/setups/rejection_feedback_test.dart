import 'package:Prism/features/setups/views/widgets/rejection_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness(String? reason, {double width = 320, TextScaler? textScaler}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: MediaQuery(
              data: MediaQueryData(textScaler: textScaler ?? TextScaler.noScaling),
              child: SizedBox(
                width: width,
                child: RejectionFeedback(reason: reason),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the reviewer reason', (WidgetTester tester) async {
    await tester.pumpWidget(harness('Please use a screenshot with the full home screen visible.'));

    expect(find.text('Please use a screenshot with the full home screen visible.'), findsOneWidget);
    expect(find.text('Review feedback'), findsOneWidget);
  });

  testWidgets('uses a helpful fallback when a legacy rejection has no reason', (WidgetTester tester) async {
    await tester.pumpWidget(harness('  '));

    expect(find.text(RejectionFeedback.fallbackReason), findsOneWidget);
  });

  testWidgets('wraps a long reason on a narrow viewport at 2x text size', (WidgetTester tester) async {
    const String reason =
        'Please replace the screenshot with a clear full-screen image and include the wallpaper, icon pack, and widget details.';
    await tester.pumpWidget(harness(reason, width: 210, textScaler: const TextScaler.linear(2)));

    expect(find.text(reason), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text(reason)).height, greaterThan(80));
  });
}
