import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the original safe-area default and accepts the caller shape', (tester) async {
    const ShapeBorder shape = RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)));
    ModalBottomSheetRoute<void>? route;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPrismSheet<void>(
              context: context,
              shape: shape,
              builder: (context) {
                route = ModalRoute.of(context)! as ModalBottomSheetRoute<void>;
                return const Text('sheet body');
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(route!.useSafeArea, isFalse);
    expect(route!.shape, shape);
  });

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
