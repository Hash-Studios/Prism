import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/popup/changelog_pop_up.dart';
import 'package:Prism/core/widgets/popup/no_load_link_pop_up.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

void main() {
  setUp(() {
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(getIt.reset);

  void expectFilledButtonReadable(WidgetTester tester, String label) {
    final FilledButton button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
    final Color background = button.style!.backgroundColor!.resolve(<WidgetState>{})!;
    final Color foreground = button.style!.foregroundColor!.resolve(<WidgetState>{})!;
    expect(contrastRatio(foreground, background), greaterThanOrEqualTo(4.5), reason: '$label button');
  }

  Future<void> open(WidgetTester tester, ThemeData theme, void Function(BuildContext) show) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => TextButton(onPressed: () => show(context), child: const Text('Open')),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    group(option.label, () {
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);

      testWidgets('sign in pop up: Google button text reads on the accent', (tester) async {
        await open(tester, theme, (context) => googleSignInPopUp(context, () {}));

        expectFilledButtonReadable(tester, 'Google');
        expect(find.text('Signing in unlocks'), findsOneWidget);
        expect(find.byType(MaterialButton), findsNothing);
      });

      testWidgets('more links pop up: Close button text reads on the accent', (tester) async {
        await open(tester, theme, (context) => showNoLoadLinksPopUp(context, <String, String>{}));

        expectFilledButtonReadable(tester, 'Close');
        expect(find.byType(MaterialButton), findsNothing);
      });

      testWidgets('changelog pop up: Close button text reads on the accent', (tester) async {
        await open(tester, theme, (context) => showChangelog(context));

        expectFilledButtonReadable(tester, 'Close');
        expect(find.text('View full'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      });
    });
  }
}
