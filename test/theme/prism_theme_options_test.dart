import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored theme ids stay unchanged', () {
    expect(prismLightThemes.map((o) => o.id), <String>['kLFrost White', 'kLCoffee', 'kLRose', 'kLCotton Blue']);
    expect(prismDarkThemes.map((o) => o.id), <String>[
      'kDMaterial Dark',
      'kDAMOLED',
      'kDSpooky',
      'kDOlive',
      'kDDeep Ocean',
      'kDJungle',
      'kDPepper',
      'kDSky',
      'kDSteel',
    ]);
  });

  test('theme display names come from localization and stored ids stay stable', () {
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(
      <String>[
        for (final option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes])
          prismThemeDisplayName(option, l10n),
      ],
      <String>[
        'Frost White',
        'Coffee',
        'Rose',
        'Cotton Blue',
        'Material Dark',
        'AMOLED',
        'Spooky',
        'Olive',
        'Deep Ocean',
        'Jungle',
        'Pepper',
        'Sky',
        'Steel',
      ],
    );
  });

  test('prismThemeById finds an option or returns null', () {
    expect(prismThemeById(prismDarkThemes, 'kDAMOLED')?.theme, kDarkTheme2);
    expect(prismThemeById(prismDarkThemes, 'missing'), isNull);
  });
}
