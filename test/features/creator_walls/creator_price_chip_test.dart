import 'package:Prism/features/creator_walls/creator_walls.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(
  theme: kLightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: home)),
);

void main() {
  testWidgets('locked chip shows the price with its label', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const CreatorPriceChip(price: 40)));

    expect(find.text('40'), findsOneWidget);
    expect(find.text('Unlocked'), findsNothing);
    expect(find.bySemanticsLabel('Premium wall, 40 coins'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('unlocked chip shows the unlocked badge instead of the price', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const CreatorPriceChip(price: 40, unlocked: true)));

    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text('40'), findsNothing);
    expect(find.bySemanticsLabel('Unlocked'), findsOneWidget);
    semantics.dispose();
  });
}
