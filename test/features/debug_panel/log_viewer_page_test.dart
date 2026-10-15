import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/debug_panel/views/pages/log_viewer_page.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _themes = <String>['Frost White', 'Material Dark', 'AMOLED'];

void main() {
  setUp(InMemoryLogSink.instance.clear);

  for (final String name in _themes) {
    testWidgets('$name: level chips read on their fill, selected or not', (tester) async {
      final PrismThemeOption option = <PrismThemeOption>[
        ...prismLightThemes,
        ...prismDarkThemes,
      ].firstWhere((PrismThemeOption o) => o.label == name);
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(backgroundColor: theme.primaryColor, body: const LogViewerPage()),
        ),
      );

      Color fillOf(String label) {
        final AnimatedContainer box = tester.widget<AnimatedContainer>(
          find.descendant(of: find.widgetWithText(PrismChip, label), matching: find.byType(AnimatedContainer)),
        );
        return Color.alphaBlend((box.decoration! as BoxDecoration).color!, theme.primaryColor);
      }

      Color labelOf(String label) => tester
          .widget<RichText>(find.descendant(of: find.widgetWithText(PrismChip, label), matching: find.byType(RichText)))
          .text
          .style!
          .color!;

      for (final String level in <String>['DBG', 'INF', 'WRN', 'ERR']) {
        expect(labelOf(level), theme.colorScheme.surface, reason: level);
        expect(contrastRatio(labelOf(level), fillOf(level)), greaterThanOrEqualTo(4.5), reason: level);
      }

      await tester.tap(find.widgetWithText(PrismChip, 'ERR'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(labelOf('ERR'), theme.colorScheme.onSurface);
      expect(contrastRatio(labelOf('ERR'), fillOf('ERR')), greaterThanOrEqualTo(4.5));
      expect(labelOf('WRN'), theme.colorScheme.surface);
    });
  }
}
