import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, ThemeData> themes = <String, ThemeData>{
    'light': kLightTheme,
    'light coffee': kLightTheme2,
    'light rose': kLightTheme3,
    'light cotton blue': kLightTheme4,
    'dark': kDarkTheme,
    'dark AMOLED': kDarkTheme2,
    'dark olive': kDarkTheme3,
    'dark deep ocean': kDarkTheme4,
    'dark jungle': kDarkTheme5,
    'dark pepper': kDarkTheme6,
    'dark sky': kDarkTheme7,
    'dark steel': kDarkTheme8,
  };

  test('all themes preserve Prism display and body type roles', () {
    for (final MapEntry<String, ThemeData> entry in themes.entries) {
      final TextTheme text = entry.value.textTheme;
      expect(text.displaySmall?.fontFamily, 'Fraunces', reason: entry.key);
      expect(text.displayMedium?.fontFamily, 'Fraunces', reason: entry.key);
      expect(text.displayLarge?.fontFamily, 'Fraunces', reason: entry.key);
      expect(text.bodyLarge?.fontFamily, 'Proxima Nova', reason: entry.key);
      expect(text.displaySmall!.fontSize! < text.displayMedium!.fontSize!, isTrue, reason: entry.key);
      expect(text.displayMedium!.fontSize! < text.displayLarge!.fontSize!, isTrue, reason: entry.key);
      expect(text.displaySmall!.fontSize! > text.bodyLarge!.fontSize!, isTrue, reason: entry.key);
    }
  });

  test('status bar icons contrast with each theme brightness', () {
    for (final MapEntry<String, ThemeData> entry in themes.entries) {
      final Brightness expected = entry.value.brightness == Brightness.dark ? Brightness.light : Brightness.dark;
      expect(entry.value.appBarTheme.systemOverlayStyle?.statusBarIconBrightness, expected, reason: entry.key);
    }
  });
}
