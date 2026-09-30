import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester, VoidCallback func) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SeeMoreButton(seeMoreLoader: false, func: func)),
      ),
    );
  }

  testWidgets('uses a square shape with no corner radius', (WidgetTester tester) async {
    await pumpButton(tester, () {});

    final MaterialButton button = tester.widget(find.byType(MaterialButton));
    expect((button.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.zero);
  });

  testWidgets('tapping See more calls func once', (WidgetTester tester) async {
    int calls = 0;
    await pumpButton(tester, () => calls++);

    await tester.tap(find.text('See more'));
    await tester.pump();

    expect(calls, 1);
  });
}
