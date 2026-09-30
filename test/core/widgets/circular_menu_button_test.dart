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

  testWidgets('a caption shows under a 48 point circle without changing the semantics label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CircularMenuButton(
            label: 'Report',
            caption: 'Report',
            isLoading: false,
            onTap: () {},
            child: const Icon(Icons.flag),
          ),
        ),
      ),
    );

    expect(find.text('Report'), findsOneWidget);
    expect(find.bySemanticsLabel('Report'), findsOneWidget);
    final Size circle = tester.getSize(
      find.descendant(of: find.byType(CircularMenuButton), matching: find.byType(SizedBox)).first,
    );
    expect(circle, const Size.square(48));
  });

  testWidgets('a loading button shows a spinner and keeps its icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CircularMenuButton(label: 'Edit', isLoading: true, child: Icon(Icons.edit)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });
}
