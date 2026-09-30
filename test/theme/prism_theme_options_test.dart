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

  test('byIdOrDefault falls back to the first theme', () {
    expect(prismLightThemes.byIdOrDefault('missing').theme, kLightTheme);
    expect(prismDarkThemes.byIdOrDefault('kDAMOLED').theme, kDarkTheme2);
    expect(prismDarkThemes.byId('missing'), isNull);
  });
}
