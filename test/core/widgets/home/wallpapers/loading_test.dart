import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BorderRadius? _firstTileRadius(WidgetTester tester) {
  final Finder tile = find.descendant(of: find.byType(GridView), matching: find.byType(DecoratedBox)).first;
  final BoxDecoration decoration = tester.widget<DecoratedBox>(tile).decoration as BoxDecoration;
  return decoration.borderRadius as BorderRadius?;
}

void main() {
  testWidgets('LoadingCards is square by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoadingCards())));
    await tester.pump();

    expect(_firstTileRadius(tester), BorderRadius.zero);
  });

  testWidgets('LoadingCards uses the given borderRadius', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoadingCards(borderRadius: BorderRadius.all(Radius.circular(20)))),
      ),
    );
    await tester.pump();

    expect(_firstTileRadius(tester), BorderRadius.circular(20));
  });
}
