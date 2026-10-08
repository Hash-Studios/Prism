import 'package:Prism/features/admin_review/biz/reject_reasons.dart';
import 'package:Prism/features/admin_review/views/widgets/reject_reason_chips.dart';
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

  testWidgets('a chip fills the text and Other clears it', (tester) async {
    final controller = TextEditingController(text: 'old');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RejectReasonChips(controller: controller)),
      ),
    );

    await tester.tap(find.text('Watermark'));
    await tester.pump();
    expect(controller.text, rejectReasons[1].text);

    await tester.tap(find.text('Other'));
    await tester.pump();
    expect(controller.text, isEmpty);
  });

  testWidgets('chips do nothing while saving', (tester) async {
    final controller = TextEditingController(text: 'keep');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RejectReasonChips(controller: controller, enabled: false)),
      ),
    );

    await tester.tap(find.text('Blurry'), warnIfMissed: false);
    await tester.pump();
    expect(controller.text, 'keep');
  });

  testWidgets('the swipe reject sheet returns the picked reason', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showRejectReasonSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duplicate'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(result, rejectReasons[4].text);
  });

  testWidgets('the sheet asks for a reason and returns null on cancel', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showRejectReasonSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pump();
    expect(find.text('Pick a reason or write one.'), findsOneWidget);
    expect(result, 'unset');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
