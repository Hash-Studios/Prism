import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
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

  testWidgets('PrimaryActionPill uses the same foreground as onColor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: const ColorScheme.light(error: midGrey)),
        home: const PrimaryActionPill(icon: Icons.check, label: 'Set', semanticLabel: 'Set', isLoading: false),
      ),
    );

    expect(tester.widget<Icon>(find.byIcon(Icons.check)).color, onColor(midGrey));
    expect(tester.widget<Text>(find.text('Set')).style?.color, onColor(midGrey));
  });
}
