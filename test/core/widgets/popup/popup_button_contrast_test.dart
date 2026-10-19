import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/popup/changelog_pop_up.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
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

  /// The button's label colour against its fill, blended over the sheet surface.
  void expectButtonReadable(WidgetTester tester, String label, ColorScheme scheme) {
    final FilledButton button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
    final Color background = Color.alphaBlend(button.style!.backgroundColor!.resolve(<WidgetState>{})!, scheme.surface);
    final Color foreground = button.style!.foregroundColor!.resolve(<WidgetState>{})!;
    expect(contrastRatio(foreground, background), greaterThanOrEqualTo(4.5), reason: '$label button');
  }

  Future<void> open(WidgetTester tester, ThemeData theme, void Function(BuildContext) show) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        theme: theme,
        home: Builder(
          builder: (context) => TextButton(onPressed: () => show(context), child: const Text('Open')),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    // Glint animates forever, so settle for a fixed time.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    group(prismThemeDisplayName(option, AppLocalizationsEn()), () {
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);

      testWidgets('sign in sheet: Google and Not now read on the surface', (tester) async {
        await open(tester, theme, (context) => googleSignInPopUp(context, () {}));

        expectButtonReadable(tester, 'Continue with Google', theme.colorScheme);
        expectButtonReadable(tester, 'Not now', theme.colorScheme);
        expect(find.text('Sign in to Prism'), findsOneWidget);
        expect(find.byType(MaterialButton), findsNothing);
      });

      testWidgets('changelog sheet: the full changelog button reads on the surface', (tester) async {
        await open(tester, theme, (context) => showChangelog(context));

        expectButtonReadable(tester, 'See the full changelog', theme.colorScheme);
        await tester.pump(const Duration(seconds: 5));
      });
    });
  }
}
