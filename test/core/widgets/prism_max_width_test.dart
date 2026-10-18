import 'package:Prism/core/widgets/prism/prism_max_width.dart';
import 'package:Prism/core/widgets/prism/prism_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Rect> _boxRect(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(
      home: PrismPage(
        title: 'Settings',
        body: SizedBox.expand(key: Key('body')),
      ),
    ),
  );
  return tester.getRect(find.byKey(const Key('body')));
}

void main() {
  testWidgets('a phone page body takes the full width', (tester) async {
    final Rect rect = await _boxRect(tester, 393);
    expect(rect.left, 0);
    expect(rect.width, 393);
  });

  testWidgets('a tablet page body is a centred 640 column', (tester) async {
    final Rect rect = await _boxRect(tester, 1376);
    expect(rect.width, 640);
    expect(rect.left, 368);
  });

  testWidgets('a grid page opts out of the column', (tester) async {
    tester.view.physicalSize = const Size(1376, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: PrismPage(
          title: 'Favourites',
          maxContentWidth: double.infinity,
          body: SizedBox.expand(key: Key('body')),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const Key('body'))).width, 1376);
  });

  testWidgets('crossing the cap keeps the child state', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 900);
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: PrismMaxWidth(child: TextField())),
      ),
    );
    final State<StatefulWidget> before = tester.state(find.byType(TextField));
    tester.view.physicalSize = const Size(1376, 900);
    await tester.pump();
    expect(identical(tester.state(find.byType(TextField)), before), isTrue);
  });
}
