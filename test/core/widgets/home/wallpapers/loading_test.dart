import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the requested tile corner radius', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoadingCards(borderRadius: BorderRadius.zero)),
      ),
    );

    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.zero);
  });

  testWidgets('preserves rounded placeholders for callers that do not opt in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoadingCards())));

    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(20));
  });
}
