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
  testWidgets('phone page bodies keep their full widths', (tester) async {
    for (final double width in <double>[320, 393, 480]) {
      final Rect rect = await _boxRect(tester, width);
      expect(rect.left, 0);
      expect(rect.width, width);
    }
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

  testWidgets('resizing a page preserves text and scroll position', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 600);
    final ScrollController scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PrismPage(
          title: 'Resize state',
          headerBottom: const TextField(key: Key('field')),
          body: ListView(
            key: const Key('list'),
            controller: scrollController,
            children: <Widget>[
              for (int index = 0; index < 12; index++) SizedBox(height: 100, child: Text('Row $index')),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('field')), 'keep this text');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    scrollController.jumpTo(300);
    await tester.pump();
    final State<StatefulWidget> fieldState = tester.state(find.byKey(const Key('field')));
    final double scrollOffset = scrollController.offset;

    tester.view.physicalSize = const Size(1376, 600);
    await tester.pump();

    expect(identical(tester.state(find.byKey(const Key('field'))), fieldState), isTrue);
    expect(find.text('keep this text'), findsOneWidget);
    expect(scrollController.offset, scrollOffset);
  });

  testWidgets('tablet body and footer columns share a center with safe-area insets', (tester) async {
    tester.view.physicalSize = const Size(1376, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(left: 24, right: 36);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: PrismPage(
          title: 'Aligned footer',
          body: SizedBox.expand(key: Key('body')),
          bottomBar: SizedBox(width: double.infinity, height: 48, key: Key('footer')),
        ),
      ),
    );

    final Rect body = tester.getRect(find.byKey(const Key('body')));
    final Rect footer = tester.getRect(find.byKey(const Key('footer')));
    expect(body.width, 640);
    expect(footer.width, 640);
    expect(body.center.dx, footer.center.dx);
  });
}
