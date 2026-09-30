import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PrismSheet opens and closes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPrismSheet<void>(context: context, builder: (_) => const Text('sheet body')),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget);
    Navigator.of(tester.element(find.text('sheet body'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsNothing);
  });
}
