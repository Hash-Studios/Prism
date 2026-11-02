import 'package:Prism/features/wallpaper_detail/views/widgets/editors_choice_label.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLabel(WidgetTester tester, {double width = 400, TextScaler textScaler = TextScaler.noScaling}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: const EditorsChoiceLabel()),
          ),
        ),
      ),
    );
  }

  testWidgets("shows the Editors' Choice title", (tester) async {
    await pumpLabel(tester);

    expect(find.text("Editors' Choice"), findsOneWidget);
  });

  testWidgets('has the picked-for semantics label', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpLabel(tester);

    expect(find.bySemanticsLabel("Picked for Editors' Choice"), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('does not overflow at 2.0 text scale in a 120 px box', (tester) async {
    await pumpLabel(tester, width: 120, textScaler: const TextScaler.linear(2.0));

    expect(tester.takeException(), isNull);
  });
}
