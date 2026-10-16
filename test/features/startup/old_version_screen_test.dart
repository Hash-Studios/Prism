import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/startup/views/pages/old_version_screen.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the update wall shows Glint, the reason and one primary action on every theme', (tester) async {
    for (final option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(theme: option.theme, home: const OldVersion()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Time to update'), findsOneWidget, reason: option.label);
      expect(find.byType(Glint), findsOneWidget, reason: option.label);
      expect(
        find.textContaining('${app_state.currentAppVersion}+${app_state.currentAppVersionCode}'),
        findsOneWidget,
        reason: option.label,
      );
      expect(find.widgetWithText(FilledButton, 'Update Prism'), findsOneWidget, reason: option.label);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, option.theme.colorScheme.surface);
    }
  });
}
