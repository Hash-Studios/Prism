import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    group(option.id, () {
      final ThemeData theme = option.theme;
      final ColorScheme cs = theme.colorScheme;
      const Set<WidgetState> off = <WidgetState>{};
      const Set<WidgetState> on = <WidgetState>{WidgetState.selected};

      test('an off switch has an outlined track and an outline thumb', () {
        final SwitchThemeData s = theme.switchTheme;
        expect(s.trackColor?.resolve(off), cs.surfaceContainerHighest);
        expect(s.trackOutlineColor?.resolve(off), cs.outline);
        expect(s.trackOutlineWidth?.resolve(off), PrismInk.switchOutlineWidth);
        expect(s.thumbColor?.resolve(off), cs.outline);
      });

      test('an on switch is the accent with no outline', () {
        final SwitchThemeData s = theme.switchTheme;
        expect(s.trackColor?.resolve(on), cs.primary);
        expect(s.thumbColor?.resolve(on), cs.onPrimary);
        expect(s.trackOutlineColor?.resolve(on), Colors.transparent);
      });

      test('a disabled filled button keeps a visible fill and a readable label', () {
        final ButtonStyle? style = theme.filledButtonTheme.style;
        const Set<WidgetState> disabled = <WidgetState>{WidgetState.disabled};
        expect(style?.backgroundColor?.resolve(disabled), cs.onSurface.withValues(alpha: 0.10));
        expect(style?.foregroundColor?.resolve(disabled), cs.onSurface.withValues(alpha: 0.6));
      });
    });
  }
}
