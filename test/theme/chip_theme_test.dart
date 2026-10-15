import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const int _violet = 0xFF7C4DFF;

PrismThemeOption _option(List<PrismThemeOption> options, String label) =>
    options.firstWhere((PrismThemeOption option) => option.label == label);

Future<void> _pump(WidgetTester tester, ThemeData theme, {required bool selected, Widget? chip}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        backgroundColor: theme.primaryColor,
        body: Center(
          child: chip ?? ChoiceChip(label: const Text('Latest'), selected: selected, onSelected: (_) {}),
        ),
      ),
    ),
  );
}

ShapeDecoration _surface(WidgetTester tester) {
  final Ink ink = tester.widget<Ink>(find.descendant(of: find.byType(RawChip), matching: find.byType(Ink)));
  return ink.decoration! as ShapeDecoration;
}

Color _labelColor(WidgetTester tester) {
  final RichText label = tester.widget<RichText>(
    find.descendant(of: find.byType(RawChip), matching: find.byType(RichText)),
  );
  return label.text.style!.color!;
}

void main() {
  final Map<String, ThemeData> themes = <String, ThemeData>{
    'Frost White': withPrismAccent(_option(prismLightThemes, 'Frost White').theme, prismDefaultAccentValue),
    'Frost White with a violet accent': withPrismAccent(_option(prismLightThemes, 'Frost White').theme, _violet),
    'AMOLED': withPrismAccent(_option(prismDarkThemes, 'AMOLED').theme, 0xFFFFFFFF),
    'AMOLED with a violet accent': withPrismAccent(_option(prismDarkThemes, 'AMOLED').theme, _violet),
  };

  for (final MapEntry<String, ThemeData> entry in themes.entries) {
    final ThemeData theme = entry.value;
    final ColorScheme scheme = theme.colorScheme;

    group(entry.key, () {
      testWidgets('a selected chip is a borderless pill filled with the accent and labelled for contrast', (
        tester,
      ) async {
        await _pump(tester, theme, selected: true);

        final ShapeDecoration surface = _surface(tester);
        expect(surface.shape, isA<StadiumBorder>());
        expect((surface.shape as StadiumBorder).side, BorderSide.none);
        expect(surface.color, scheme.primary);
        expect(_labelColor(tester), onColor(scheme.primary));
      });

      testWidgets('an unselected chip is a tonal pill and its label is the theme foreground', (tester) async {
        await _pump(tester, theme, selected: false);

        final ShapeDecoration surface = _surface(tester);
        expect(surface.shape, isA<StadiumBorder>());
        expect(surface.color, isNot(scheme.primary));
        expect(surface.color!.a, lessThan(0.2));
        expect(_labelColor(tester), scheme.secondary);
      });

      testWidgets('selecting a chip does not change its width, because there is no checkmark', (tester) async {
        await _pump(tester, theme, selected: false);
        final Size unselected = tester.getSize(find.byType(ChoiceChip));
        await _pump(tester, theme, selected: true);
        await tester.pumpAndSettle();
        final Size selected = tester.getSize(find.byType(ChoiceChip));

        expect(selected, unselected);
      });

      testWidgets('a filter chip looks the same as a choice chip', (tester) async {
        await _pump(
          tester,
          theme,
          selected: true,
          chip: FilterChip(label: const Text('Latest'), selected: true, onSelected: (_) {}),
        );

        expect(_surface(tester).color, scheme.primary);
        expect(_labelColor(tester), onColor(scheme.primary));
      });

      testWidgets('a chip is 36 px tall inside a 48 px tap target', (tester) async {
        await _pump(tester, theme, selected: false);

        expect(tester.getSize(find.byType(ChoiceChip)).height, 48);
        expect(tester.getSize(find.descendant(of: find.byType(RawChip), matching: find.byType(Ink))).height, 36);
      });
    });
  }

  testWidgets('a new accent changes the selected chip fill', (tester) async {
    final ThemeData pink = themes['Frost White']!;
    final ThemeData violet = themes['Frost White with a violet accent']!;

    await _pump(tester, pink, selected: true);
    final Color pinkFill = _surface(tester).color!;
    await _pump(tester, violet, selected: true);
    await tester.pumpAndSettle();

    expect(pinkFill, const Color(prismDefaultAccentValue));
    expect(_surface(tester).color, const Color(_violet));
  });

  testWidgets('a disabled chip has the rest fill and a label at half strength', (tester) async {
    final ThemeData theme = themes['Frost White']!;
    await _pump(tester, theme, selected: false, chip: const ChoiceChip(label: Text('Latest'), selected: false));

    expect(_surface(tester).color, const Color(0xFF2F2F2F).withValues(alpha: 0.08));
    expect(_labelColor(tester), const Color(0xFF2F2F2F).withValues(alpha: 0.5));
  });

  testWidgets('an avatar gets a 24 px wide box, so the icon keeps clear of the rounded end', (tester) async {
    final ThemeData theme = themes['Frost White']!;
    await _pump(tester, theme, selected: false, chip: const ActionChip(label: Text('Latest')));
    final double plain = tester.getSize(find.byType(ActionChip)).width;
    await _pump(
      tester,
      theme,
      selected: false,
      chip: const ActionChip(avatar: Icon(Icons.history_rounded), label: Text('Latest')),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ActionChip)).width - plain, 24);
    expect(tester.getSize(find.byIcon(Icons.history_rounded)), const Size(16, 16));
  });

  group('readable ink', () {
    const Map<String, Color> inkByTheme = <String, Color>{
      'Rose': Color(0xFF4B342D),
      'Cotton Blue': Color(0xFF202836),
      'Coffee': Color(0xFF785C23),
      'Frost White': Color(0xFF2F2F2F),
      'AMOLED': Color(0xFFFFFFFF),
    };

    for (final MapEntry<String, Color> entry in inkByTheme.entries) {
      test('${entry.key}: the ink is ${entry.value.toARGB32().toRadixString(16)} and reads on the page', () {
        final PrismThemeOption option = <PrismThemeOption>[
          ...prismLightThemes,
          ...prismDarkThemes,
        ].firstWhere((PrismThemeOption o) => o.label == entry.key);
        final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);

        expect(prismReadableInk(theme).toARGB32(), entry.value.toARGB32());
        expect(contrastRatio(prismReadableInk(theme), theme.primaryColor), greaterThanOrEqualTo(4.5));
      });
    }

    test('a theme with a strong foreground softens the secondary ink to 80 percent', () {
      final ThemeData theme = themes['Frost White']!;

      expect(prismSoftInk(theme), const Color(0xFF2F2F2F).withValues(alpha: 0.8));
    });

    test('a theme with a weak foreground keeps full ink, because 80 percent would read under 4.5:1', () {
      final PrismThemeOption rose = prismLightThemes.firstWhere((PrismThemeOption o) => o.label == 'Rose');
      final ThemeData theme = withPrismAccent(rose.theme, rose.defaultAccentValue);
      final Color soft = const Color(0xFF4B342D).withValues(alpha: 0.8);

      expect(contrastRatio(Color.alphaBlend(soft, theme.primaryColor), theme.primaryColor), lessThan(4.5));
      expect(prismSoftInk(theme).toARGB32(), 0xFF4B342D);
    });

    for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
      test('${option.label}: the soft ink reads on the page at 4.5:1', () {
        final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);

        expect(
          contrastRatio(Color.alphaBlend(prismSoftInk(theme), theme.primaryColor), theme.primaryColor),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    testWidgets('${option.label}: chip labels read on their fills at the default accent', (tester) async {
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);

      await _pump(tester, theme, selected: false);
      final Color restFill = Color.alphaBlend(_surface(tester).color!, theme.primaryColor);
      expect(contrastRatio(_labelColor(tester), restFill), greaterThanOrEqualTo(4.5), reason: 'unselected');

      await _pump(tester, theme, selected: true);
      await tester.pumpAndSettle();
      expect(
        contrastRatio(_labelColor(tester), _surface(tester).color!),
        greaterThanOrEqualTo(4.5),
        reason: 'selected',
      );
    });
  }
}
