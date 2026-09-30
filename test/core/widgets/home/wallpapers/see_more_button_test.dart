import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester, VoidCallback func, {bool isDark = false, bool loading = false}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
        home: Scaffold(
          body: SeeMoreButton(seeMoreLoader: loading, func: func),
        ),
      ),
    );
  }

  testWidgets('renders the button surface and splash with square corners', (WidgetTester tester) async {
    await pumpButton(tester, () {});

    final Finder button = find.byType(MaterialButton);
    final Material surface = tester.widget(find.descendant(of: button, matching: find.byType(Material)));
    final InkWell splash = tester.widget(find.descendant(of: button, matching: find.byType(InkWell)));

    expect((surface.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.zero);
    expect((splash.customBorder! as RoundedRectangleBorder).borderRadius, BorderRadius.zero);
  });

  testWidgets('fills a constrained grid cell and accepts taps at its square corner', (WidgetTester tester) async {
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 240,
            child: GridView.count(
              crossAxisCount: 1,
              children: <Widget>[SeeMoreButton(seeMoreLoader: false, func: () => calls++)],
            ),
          ),
        ),
      ),
    );

    final Finder button = find.byType(MaterialButton);
    expect(tester.getSize(button), const Size(240, 240));
    final Offset topLeft = tester.getTopLeft(button);
    await tester.tapAt(topLeft + const Offset(1, 1));

    expect(calls, 1);
  });

  testWidgets('uses the light surface color', (WidgetTester tester) async {
    await pumpButton(tester, () {});
    expect(tester.widget<MaterialButton>(find.byType(MaterialButton)).color, Colors.black.withValues(alpha: .1));
  });

  testWidgets('uses the dark surface color', (WidgetTester tester) async {
    await pumpButton(tester, () {}, isDark: true);
    expect(tester.widget<MaterialButton>(find.byType(MaterialButton)).color, Colors.white10);
  });

  testWidgets('shows the loader instead of the label while loading', (WidgetTester tester) async {
    await pumpButton(tester, () {}, loading: true);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('See more'), findsNothing);
  });

  testWidgets('tapping See more calls func once', (WidgetTester tester) async {
    int calls = 0;
    await pumpButton(tester, () => calls++);

    await tester.tap(find.text('See more'));
    await tester.pump();

    expect(calls, 1);
  });
}
