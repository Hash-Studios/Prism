import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:Prism/features/folders/views/widgets/smart_rules_line.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const SmartRule _blue = SmartRule(SmartRuleKind.colour, 'blue');
const SmartRule _teal = SmartRule(SmartRuleKind.colour, 'teal');
const SmartRule _followed = SmartRule(SmartRuleKind.followed);
const SmartRule _creator = SmartRule(SmartRuleKind.creator, 'c1');

Future<void> _pumpLine(WidgetTester tester, SmartRulesLine line) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: kLightTheme,
    home: Scaffold(body: line),
  ),
);

void main() {
  testWidgets('shows the summary, the Edit rules button, and the Rules semantics label', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int edits = 0;
    await _pumpLine(
      tester,
      SmartRulesLine(
        rules: const <SmartRule>[_blue, _teal, _followed],
        onEdit: () => edits++,
        loadCreatorNames: (_) async => const <String, String>{},
      ),
    );
    await tester.pump();

    const String summary = 'Colour: Blue, Teal · Creators I follow';
    expect(find.text(summary), findsOneWidget);
    expect(find.bySemanticsLabel('Rules: $summary'), findsOneWidget);
    expect(find.text('Edit rules'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('smart-rules-edit')));
    expect(edits, 1);
    semantics.dispose();
  });

  testWidgets('hides the Edit rules button when onEdit is null', (tester) async {
    await _pumpLine(
      tester,
      SmartRulesLine(rules: const <SmartRule>[_blue], loadCreatorNames: (_) async => const <String, String>{}),
    );
    await tester.pump();

    expect(find.text('Colour: Blue'), findsOneWidget);
    expect(find.text('Edit rules'), findsNothing);
    expect(find.byKey(const ValueKey<String>('smart-rules-edit')), findsNothing);
  });

  testWidgets('a creator rule shows the creator name from loadCreatorNames', (tester) async {
    await _pumpLine(
      tester,
      SmartRulesLine(
        rules: const <SmartRule>[_creator],
        loadCreatorNames: (uids) async => const <String, String>{'c1': '@ana'},
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Creator: @ana'), findsOneWidget);
  });
}
