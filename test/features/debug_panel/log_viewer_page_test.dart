import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/features/debug_panel/views/pages/log_viewer_page.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Expected = ({String theme, int selectedLabel, int unselectedLabel});

const List<_Expected> _themes = <_Expected>[
  (theme: 'Frost White', selectedLabel: 0xFF000000, unselectedLabel: 0xFF2F2F2F),
  (theme: 'Material Dark', selectedLabel: 0xFFFFFFFF, unselectedLabel: 0xFFF0F0F0),
  (theme: 'AMOLED', selectedLabel: 0xFFFFFFFF, unselectedLabel: 0xFFFFFFFF),
];

void main() {
  setUp(InMemoryLogSink.instance.clear);

  for (final _Expected expected in _themes) {
    testWidgets('${expected.theme}: level chips keep their colour fill and a label that reads on it', (tester) async {
      final PrismThemeOption option = <PrismThemeOption>[
        ...prismLightThemes,
        ...prismDarkThemes,
      ].firstWhere((PrismThemeOption o) => o.label == expected.theme);
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(backgroundColor: theme.primaryColor, body: const LogViewerPage()),
        ),
      );

      Color fillOf(String label) {
        final Ink ink = tester.widget<Ink>(
          find.descendant(of: find.widgetWithText(FilterChip, label), matching: find.byType(Ink)),
        );
        return Color.alphaBlend((ink.decoration! as ShapeDecoration).color!, theme.primaryColor);
      }

      Color labelOf(String label) => tester
          .widget<RichText>(
            find.descendant(of: find.widgetWithText(FilterChip, label), matching: find.byType(RichText)),
          )
          .text
          .style!
          .color!;

      for (final String level in <String>['DBG', 'INF', 'WRN', 'ERR']) {
        expect(labelOf(level).toARGB32(), expected.selectedLabel, reason: level);
        expect(contrastRatio(labelOf(level), fillOf(level)), greaterThanOrEqualTo(4.5), reason: level);
      }

      await tester.tap(find.widgetWithText(FilterChip, 'ERR'));
      await tester.pumpAndSettle();

      expect(labelOf('ERR').toARGB32(), expected.unselectedLabel);
      expect(contrastRatio(labelOf('ERR'), fillOf('ERR')), greaterThanOrEqualTo(4.5));
      expect(labelOf('WRN').toARGB32(), expected.selectedLabel);
    });
  }
}
