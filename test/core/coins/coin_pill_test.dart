import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  for (final ThemeData theme in <ThemeData>[ThemeData.light(), ThemeData.dark()]) {
    final String mode = theme.brightness.name;

    testWidgets('coin pill shows the balance and a tap target of 44 when tappable ($mode)', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      int taps = 0;
      await tester.pumpWidget(_app(theme, CoinBalancePill(balance: 240, onTap: () => taps++)));
      expect(find.text('240'), findsOneWidget);
      expect(find.bySemanticsLabel('240 Prism coins'), findsOneWidget);
      expect(tester.getSize(find.byType(StatPill)).height, greaterThanOrEqualTo(44));

      final SemanticsNode button = tester.getSemantics(find.bySemanticsLabel('240 Prism coins'));
      expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: button.id),
      );
      await tester.pump();
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('coin pill shows the change with an arrow, not only a colour ($mode)', (tester) async {
      await tester.pumpWidget(_app(theme, const CoinBalancePill(balance: 250, delta: 10)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.pumpWidget(_app(theme, const CoinBalancePill(balance: 240, delta: -10)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });
  }
}
