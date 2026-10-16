import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
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

  testWidgets('has the wallpaper tile shape', (WidgetTester tester) async {
    await pumpButton(tester, () {});

    final Material surface = tester.widget(
      find.descendant(of: find.byType(SeeMoreButton), matching: find.byType(Material)).first,
    );
    expect(surface.borderRadius, PrismWallGrid.tileRadius);
  });

  testWidgets('fills a constrained grid cell and accepts taps near its corner', (WidgetTester tester) async {
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

    final Finder button = find.byType(SeeMoreButton);
    expect(tester.getSize(button), const Size(240, 240));
    await tester.tapAt(tester.getTopLeft(button) + const Offset(8, 8));

    expect(calls, 1);
  });

  testWidgets('follows the theme in light and dark', (WidgetTester tester) async {
    for (final bool dark in <bool>[false, true]) {
      await pumpButton(tester, () {}, isDark: dark);
      final BuildContext context = tester.element(find.byType(SeeMoreButton));
      final Material surface = tester.widget(
        find.descendant(of: find.byType(SeeMoreButton), matching: find.byType(Material)).first,
      );
      expect(surface.color, Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08));
    }
  });

  testWidgets('does not call func while loading', (WidgetTester tester) async {
    int calls = 0;
    await pumpButton(tester, () => calls++, loading: true);
    await tester.tap(find.byType(SeeMoreButton));
    expect(calls, 0);
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
