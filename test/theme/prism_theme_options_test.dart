import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored theme ids stay unchanged', () {
    expect(prismLightThemes.map((o) => o.id), <String>['kLFrost White', 'kLCoffee', 'kLRose', 'kLCotton Blue']);
    expect(prismDarkThemes.map((o) => o.id), <String>[
      'kDMaterial Dark',
      'kDAMOLED',
      'kDOlive',
      'kDDeep Ocean',
      'kDJungle',
      'kDPepper',
      'kDSky',
      'kDSteel',
    ]);
  });

  test('labels are the ids without the light or dark prefix', () {
    for (final option in [...prismLightThemes, ...prismDarkThemes]) {
      expect(option.label, option.id.substring(2));
    }
  });

  test('prismThemeById finds an option or returns null', () {
    expect(prismThemeById(prismDarkThemes, 'kDAMOLED')?.theme, kDarkTheme2);
    expect(prismThemeById(prismDarkThemes, 'missing'), isNull);
  });
}
