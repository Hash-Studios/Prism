import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Color midGrey = Color(0xFF808080);

  test('onColor switches at the WCAG crossover luminance of 0.179', () {
    expect(midGrey.computeLuminance(), inExclusiveRange(0.179, 0.5));
    expect(onColor(midGrey), Colors.black);
    expect(onColor(Colors.white), Colors.black);
    expect(onColor(Colors.black), Colors.white);
    expect(onColor(const Color(0xFF595959)), Colors.white);
  });

  Future<void> pumpPill(WidgetTester tester, {required bool loading}) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      theme: ThemeData(colorScheme: const ColorScheme.light(primary: midGrey)),
      home: Center(
        child: PrimaryActionPill(label: 'Save', semanticLabel: 'Save', isLoading: loading),
      ),
    ),
  );

  testWidgets('PrimaryActionPill uses the same foreground as onColor', (tester) async {
    await pumpPill(tester, loading: false);
    expect(tester.widget<Text>(find.text('Save')).style?.color, onColor(midGrey));

    await pumpPill(tester, loading: true);
    expect(tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).color, onColor(midGrey));
  });

  testWidgets('PrimaryActionPill keeps its width while the spinner replaces the label', (tester) async {
    await pumpPill(tester, loading: false);
    final Size idle = tester.getSize(find.byType(PrimaryActionPill));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await pumpPill(tester, loading: true);
    expect(tester.getSize(find.byType(PrimaryActionPill)), idle);
    expect(tester.widget<Opacity>(find.ancestor(of: find.text('Save'), matching: find.byType(Opacity))).opacity, 0);
  });
}
