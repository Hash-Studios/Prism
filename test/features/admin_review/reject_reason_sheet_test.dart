import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/reject_reasons.dart';
import 'package:Prism/features/admin_review/views/widgets/reject_reason_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every preset except Other has creator-facing text without an email or blame', () {
    expect(rejectReasons.map((r) => r.label), <String>[
      'Low resolution',
      'Watermark',
      'Blurry',
      'Copyright',
      'Duplicate',
      'Not a wallpaper',
      'Other',
    ]);
    for (final reason in rejectReasons.where((r) => r.label != 'Other')) {
      expect(reason.text, isNotEmpty, reason: reason.label);
      expect(reason.text, isNot(contains('@')), reason: reason.label);
    }
    expect(rejectReasons.last.text, isEmpty);
  });

  Future<void> openSheet(WidgetTester tester, Future<void> Function(String reason) onSubmit) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRejectReasonSheet(context, onSubmit: onSubmit),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a chip fills the text and Other clears it', (tester) async {
    await openSheet(tester, (_) async {});

    await tester.tap(find.text('Watermark'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, rejectReasons[1].text);

    await tester.tap(find.text('Other'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('the sheet submits the picked reason, which is how a swipe reject reads it', (tester) async {
    String? result;
    await openSheet(tester, (reason) async => result = reason);

    await tester.tap(find.text('Duplicate'));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pumpAndSettle();

    expect(result, rejectReasons[4].text);
    expect(find.byType(PrismSheetBody), findsNothing);
  });

  testWidgets('the sheet asks for a reason and submits nothing on cancel', (tester) async {
    String? result = 'unset';
    await openSheet(tester, (reason) async => result = reason);

    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pump();
    expect(find.text('Enter a reason before rejecting this item.'), findsOneWidget);
    expect(result, 'unset');

    await tester.tap(find.widgetWithText(PrismButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, 'unset');
    expect(find.byType(PrismSheetBody), findsNothing);
  });
}
