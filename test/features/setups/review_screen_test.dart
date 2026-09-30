import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/setups/views/pages/review_screen.dart';
import 'package:Prism/features/setups/views/widgets/rejection_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(String? reason, {double width = 390, TextScaler? textScaler}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MediaQuery(
            data: MediaQueryData(size: Size(width, 844), textScaler: textScaler ?? TextScaler.noScaling),
            child: SizedBox(
              width: width,
              child: SetupTile(
                FirestoreDocument('setup-1', <String, dynamic>{'rejectionReason': reason}),
                false,
                rejected: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final double width in <double>[360, 390]) {
    testWidgets('long rejection feedback fits a ${width.toInt()}px setup tile', (WidgetTester tester) async {
      const String reason =
          'Please replace the screenshot with a clear full-screen image and include the wallpaper, icon pack, and widget details.';
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness(reason, width: width));

      expect(find.text(reason), findsOneWidget);
      expect(tester.getSize(find.byType(SetupTile)).height, greaterThan(430));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a pending wall tile with a 20-character Firestore id fits a 440px screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WallTile(
              FirestoreDocument('pWTbDtblpDvZpVsYZbjt', <String, dynamic>{
                'createdAt': DateTime.utc(2026, 9, 30),
                'size': '0.25MB',
                'resolution': '1080x2160',
              }),
              rejected: false,
            ),
          ),
        ),
      ),
    );
    // The Ahem test font is taller than real fonts, so only the horizontal fit is asserted here.
    tester.takeException();

    expect(
      tester.getRect(find.text('pWTbDtblpDvZpVsYZbjt')).right,
      lessThanOrEqualTo(tester.getRect(find.byType(Card)).right),
    );
  });

  testWidgets('a legacy rejected setup without a reason shows the fallback in its tile', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness('  '));

    expect(find.text(RejectionFeedback.fallbackReason), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
