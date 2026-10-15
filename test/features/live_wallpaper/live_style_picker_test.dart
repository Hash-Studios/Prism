import 'package:Prism/features/live_wallpaper/views/widgets/live_style_picker.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final PrismThemeOption frost = prismLightThemes.first;
  final ThemeData theme = withPrismAccent(frost.theme, frost.defaultAccentValue);

  Future<void> pump(WidgetTester tester, {required ValueChanged<String> onSelected}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: LiveStylePicker<String>(
            values: const <String>['Aurora', 'Ripple', 'Plain'],
            selected: 'Ripple',
            label: (String value) => value,
            isLocked: (String value) => value != 'Plain',
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('the chosen style is the accent pill and the others are tonal', (tester) async {
    await pump(tester, onSelected: (_) {});

    Color fillOf(String label) {
      final Ink ink = tester.widget<Ink>(
        find.descendant(of: find.widgetWithText(ChoiceChip, label), matching: find.byType(Ink)),
      );
      return (ink.decoration! as ShapeDecoration).color!;
    }

    expect(fillOf('Ripple'), theme.colorScheme.primary);
    expect(fillOf('Aurora'), isNot(theme.colorScheme.primary));
  });

  testWidgets('a locked style keeps its lock readable, chosen or not', (tester) async {
    await pump(tester, onSelected: (_) {});

    final Icon chosenLock = tester.widget<Icon>(
      find.descendant(of: find.widgetWithText(ChoiceChip, 'Ripple'), matching: find.byIcon(Icons.lock_outline_rounded)),
    );
    final BuildContext otherLock = tester.element(
      find.descendant(of: find.widgetWithText(ChoiceChip, 'Aurora'), matching: find.byIcon(Icons.lock_outline_rounded)),
    );

    expect(chosenLock.color, onColor(theme.colorScheme.primary));
    expect(IconTheme.of(otherLock).color, theme.colorScheme.secondary);
    expect(find.descendant(of: find.widgetWithText(ChoiceChip, 'Plain'), matching: find.byType(Icon)), findsNothing);
  });

  testWidgets('tapping a style reports it', (tester) async {
    String? picked;
    await pump(tester, onSelected: (value) => picked = value);

    await tester.tap(find.text('Aurora'));

    expect(picked, 'Aurora');
  });
}
