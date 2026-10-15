import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('icon-only action buttons are labelled tappable buttons', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CircularMenuButton(
            label: 'Share',
            isLoading: false,
            onTap: () => taps++,
            child: const Icon(Icons.share),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder share = find.bySemanticsLabel('Share');
    expect(share, findsOneWidget);
    expect(tester.getSemantics(share), matchesSemantics(label: 'Share', isButton: true, hasTapAction: true));

    await tester.tap(share);
    expect(taps, 1);
  });

  testWidgets('toggle buttons such as Favourite announce whether they are on', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CircularMenuButton(label: 'Favourite', isLoading: false, selected: true, child: Icon(Icons.favorite)),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Favourite')),
      isSemantics(label: 'Favourite', isButton: true, isSelected: true),
    );
  });

  testWidgets('a flat button takes a tap on its padding, not only on the glyph', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: FlatMenuButtons(
            child: CircularMenuButton(
              label: 'Share',
              isLoading: false,
              onTap: () => taps++,
              child: const Icon(Icons.share, size: 20),
            ),
          ),
        ),
      ),
    );
    final Offset centre = tester.getCenter(find.byType(CircularMenuButton));
    expect(tester.getSize(find.byType(CircularMenuButton)), const Size(54, 54));

    await tester.tapAt(centre + const Offset(14, 0));
    await tester.tapAt(centre + const Offset(0, -14));
    expect(taps, 2);

    await tester.tapAt(centre + const Offset(40, 0));
    expect(taps, 2);
  });
}
