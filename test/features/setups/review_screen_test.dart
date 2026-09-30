import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/setups/views/pages/review_screen.dart';
import 'package:Prism/features/setups/views/widgets/rejection_feedback.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('Proxima Nova')..addFont(rootBundle.load('assets/fonts/ProximaNova-Regular.otf'))).load();
  });

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

  for (final double width in <double>[360, 390, 440]) {
    for (final bool rejected in <bool>[false, true]) {
      for (final double textScale in <double>[1, 1.5]) {
        testWidgets(
          '${rejected ? 'rejected' : 'pending'} wall tile content stays within a ${width.toInt()}px card at ${textScale}x text',
          (WidgetTester tester) async {
            tester.view.physicalSize = Size(width, 956);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: kLightTheme,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: MediaQuery(
                      data: MediaQueryData(size: Size(width, 956), textScaler: TextScaler.linear(textScale)),
                      child: WallTile(
                        FirestoreDocument('pWTbDtblpDvZpVsYZbjt', <String, dynamic>{
                          'createdAt': DateTime.utc(2026, 9, 30),
                          'size': '12.34MB',
                          'resolution': '1440x3200',
                          if (rejected)
                            'rejectionReason':
                                'Please replace the screenshot with a clear full-screen image and include the wallpaper, icon pack, and widget details.',
                        }),
                        rejected: rejected,
                      ),
                    ),
                  ),
                ),
              ),
            );

            final Rect cardRect = tester.getRect(find.byType(Card));
            final Finder cardText = find.descendant(of: find.byType(Card), matching: find.byType(Text));
            for (final Element text in cardText.evaluate()) {
              final Rect textRect = tester.getRect(find.byWidget(text.widget));
              expect(textRect.left, greaterThanOrEqualTo(cardRect.left));
              expect(textRect.right, lessThanOrEqualTo(cardRect.right));
              expect(textRect.bottom, lessThanOrEqualTo(cardRect.bottom));
            }
            expect(tester.getRect(find.byType(ActionChip)).bottom, lessThanOrEqualTo(cardRect.bottom));
            final Finder iconButtons = find.byType(IconButton);
            expect(iconButtons, findsNWidgets(2));
            for (int index = 0; index < 2; index++) {
              final Rect button = tester.getRect(iconButtons.at(index));
              expect(button.left, greaterThanOrEqualTo(cardRect.left));
              expect(button.right, lessThanOrEqualTo(cardRect.right));
              expect(button.bottom, lessThanOrEqualTo(cardRect.bottom));
              expect(button.width, greaterThanOrEqualTo(48));
            }
            expect(tester.takeException(), isNull);

            final Finder idFinder = find.text('pWTbDtblpDvZpVsYZbjt');
            final Text idText = tester.widget<Text>(idFinder);
            expect(idText.maxLines, 1);
            expect(idText.overflow, TextOverflow.ellipsis);
            if (width == 360) {
              expect(tester.renderObject<RenderParagraph>(idFinder).didExceedMaxLines, isTrue);
            }
            if (rejected) {
              expect(find.byType(RejectionFeedback), findsOneWidget);
            }
          },
        );
      }
    }
  }

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
