import 'package:Prism/features/theme_mode/data/account_theme.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object> _wire() => <String, Object>{
  'mode': 'dark',
  'lightThemeId': 'kLFrost White',
  'lightAccent': 0xffe57697,
  'darkThemeId': 'kDOlive',
  'darkAccent': 0xff767b45,
  'changedAt': 1767225600000,
};

ThemePreferences _prefs({
  required String lightId,
  required int lightAccent,
  required String darkId,
  required int darkAccent,
  ThemeMode mode = ThemeMode.light,
}) => ThemePreferences(
  light: ThemeSelection(themeId: lightId, accentColorValue: lightAccent),
  dark: ThemeSelection(themeId: darkId, accentColorValue: darkAccent),
  mode: mode,
);

void main() {
  group('AccountTheme wire shape', () {
    test('toMap then fromMap round-trips every field', () {
      final AccountTheme original = AccountTheme(
        preferences: _prefs(
          lightId: 'kLFrost White',
          lightAccent: 0xffe57697,
          darkId: 'kDOlive',
          darkAccent: 0xff767b45,
          mode: ThemeMode.dark,
        ),
        changedAt: 1767225600000,
      );

      final Map<String, Object> wire = original.toMap();
      final AccountTheme? decoded = AccountTheme.fromMap(wire);

      expect(wire, _wire());
      expect(decoded, isNotNull);
      expect(decoded!.changedAt, 1767225600000);
      expect(decoded.preferences.mode, ThemeMode.dark);
      expect(decoded.preferences.light.themeId, 'kLFrost White');
      expect(decoded.preferences.light.accentColorValue, 0xffe57697);
      expect(decoded.preferences.dark.themeId, 'kDOlive');
      expect(decoded.preferences.dark.accentColorValue, 0xff767b45);
    });

    test('toMap then fromMap keeps the Material You ids unchanged', () {
      final AccountTheme original = AccountTheme(
        preferences: _prefs(
          lightId: 'kLMaterial You',
          lightAccent: 0xffe57697,
          darkId: 'kDMaterial You',
          darkAccent: 0xff767b45,
          mode: ThemeMode.system,
        ),
        changedAt: 1767225600000,
      );

      final Map<String, Object> wire = original.toMap();
      final AccountTheme? decoded = AccountTheme.fromMap(wire);

      expect(wire['lightThemeId'], 'kLMaterial You');
      expect(wire['darkThemeId'], 'kDMaterial You');
      expect(decoded, isNotNull);
      expect(decoded!.preferences.light.themeId, 'kLMaterial You');
      expect(decoded.preferences.dark.themeId, 'kDMaterial You');
      expect(decoded.preferences.mode, ThemeMode.system);
    });

    test('fromMap accepts a whole-number double for an int field', () {
      final Map<String, Object> wire = _wire()..['changedAt'] = 1767225600000.0;

      expect(AccountTheme.fromMap(wire)?.changedAt, 1767225600000);
    });

    test('fromMap returns null for null and non-map input', () {
      expect(AccountTheme.fromMap(null), isNull);
      expect(AccountTheme.fromMap('themePrefs'), isNull);
      expect(AccountTheme.fromMap(42), isNull);
    });

    test('fromMap returns null when a key is missing', () {
      final Map<String, Object> wire = _wire()..remove('darkAccent');

      expect(AccountTheme.fromMap(wire), isNull);
    });

    test('fromMap returns null when a value has the wrong type', () {
      final Map<String, Object> wire = _wire()..['lightAccent'] = '0xffe57697';

      expect(AccountTheme.fromMap(wire), isNull);
    });

    test('fromMap returns null for an unknown mode', () {
      final Map<String, Object> wire = _wire()..['mode'] = 'sepia';

      expect(AccountTheme.fromMap(wire), isNull);
    });

    test('fromMap returns null for an empty theme id', () {
      final Map<String, Object> wire = _wire()..['lightThemeId'] = '';

      expect(AccountTheme.fromMap(wire), isNull);
    });
  });

  group('mergeAccountTheme', () {
    final ThemePreferences local = _prefs(
      lightId: 'kLFrost White',
      lightAccent: 0xffe57697,
      darkId: 'kDMaterial Dark',
      darkAccent: 0xff123456,
      mode: ThemeMode.dark,
    );

    test('applies a free account theme in both slots', () {
      final ThemePreferences account = _prefs(
        lightId: 'kLCoffee',
        lightAccent: 0xffc19439,
        darkId: 'kDAMOLED',
        darkAccent: 0xffffffff,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: local,
        owned: const <String>{},
        legacyThemes: const <String>{},
      );

      expect(merged.light.themeId, 'kLCoffee');
      expect(merged.light.accentColorValue, 0xffc19439);
      expect(merged.dark.themeId, 'kDAMOLED');
      expect(merged.dark.accentColorValue, 0xffffffff);
    });

    test('keeps local id and accent for a paid light theme not owned', () {
      final ThemePreferences account = _prefs(
        lightId: 'kLRose',
        lightAccent: 0xffa7796d,
        darkId: 'kDMaterial Dark',
        darkAccent: 0xff123456,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: local,
        owned: const <String>{},
        legacyThemes: const <String>{},
      );

      expect(merged.light.themeId, 'kLFrost White');
      expect(merged.light.accentColorValue, 0xffe57697);
    });

    test('keeps local id and accent for a paid dark theme not owned', () {
      final ThemePreferences account = _prefs(
        lightId: 'kLFrost White',
        lightAccent: 0xffe57697,
        darkId: 'kDOlive',
        darkAccent: 0xff767b45,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: local,
        owned: const <String>{},
        legacyThemes: const <String>{},
      );

      expect(merged.dark.themeId, 'kDMaterial Dark');
      expect(merged.dark.accentColorValue, 0xff123456);
    });

    test('applies a paid dark theme when owned contains its shop item', () {
      final ThemePreferences account = _prefs(
        lightId: 'kLFrost White',
        lightAccent: 0xffe57697,
        darkId: 'kDOlive',
        darkAccent: 0xff767b45,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: local,
        owned: const <String>{'theme_olive'},
        legacyThemes: const <String>{},
      );

      expect(merged.dark.themeId, 'kDOlive');
      expect(merged.dark.accentColorValue, 0xff767b45);
    });

    test('applies a paid light theme when legacyThemes contains its id', () {
      final ThemePreferences account = _prefs(
        lightId: 'kLRose',
        lightAccent: 0xffa7796d,
        darkId: 'kDMaterial Dark',
        darkAccent: 0xff123456,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: local,
        owned: const <String>{},
        legacyThemes: const <String>{'kLRose'},
      );

      expect(merged.light.themeId, 'kLRose');
      expect(merged.light.accentColorValue, 0xffa7796d);
    });

    test('applies a paid light theme when it equals the local selected id', () {
      final ThemePreferences localRose = _prefs(
        lightId: 'kLRose',
        lightAccent: 0xff111111,
        darkId: 'kDMaterial Dark',
        darkAccent: 0xff123456,
      );
      final ThemePreferences account = _prefs(
        lightId: 'kLRose',
        lightAccent: 0xffa7796d,
        darkId: 'kDMaterial Dark',
        darkAccent: 0xff123456,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: localRose,
        owned: const <String>{},
        legacyThemes: const <String>{},
      );

      expect(merged.light.themeId, 'kLRose');
      expect(merged.light.accentColorValue, 0xffa7796d);
    });

    test('keeps local selection for an unknown theme id', () {
      final ThemePreferences account = _prefs(
        lightId: 'kLFrost White',
        lightAccent: 0xffe57697,
        darkId: 'kDNope',
        darkAccent: 0xff00ff00,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: local,
        owned: const <String>{},
        legacyThemes: const <String>{},
      );

      expect(merged.dark.themeId, 'kDMaterial Dark');
      expect(merged.dark.accentColorValue, 0xff123456);
    });

    test('mode always follows the account', () {
      final ThemePreferences account = _prefs(
        lightId: 'kLFrost White',
        lightAccent: 0xffe57697,
        darkId: 'kDMaterial Dark',
        darkAccent: 0xff123456,
        mode: ThemeMode.system,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: local,
        owned: const <String>{},
        legacyThemes: const <String>{},
      );

      expect(merged.mode, ThemeMode.system);
    });

    test('keeps Material You in both slots when the account has it and the local themes are free', () {
      final ThemePreferences localCoffeeAmoled = _prefs(
        lightId: 'kLCoffee',
        lightAccent: 0xffc19439,
        darkId: 'kDAMOLED',
        darkAccent: 0xffffffff,
      );
      final ThemePreferences account = _prefs(
        lightId: 'kLMaterial You',
        lightAccent: 0xff111111,
        darkId: 'kDMaterial You',
        darkAccent: 0xff222222,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: localCoffeeAmoled,
        owned: const <String>{},
        legacyThemes: const <String>{},
      );

      expect(merged.light.themeId, 'kLMaterial You');
      expect(merged.light.accentColorValue, 0xff111111);
      expect(merged.dark.themeId, 'kDMaterial You');
      expect(merged.dark.accentColorValue, 0xff222222);
    });

    test('keeps local light selection when the account puts the dark Material You id in the light slot', () {
      final ThemePreferences account = _prefs(
        lightId: 'kDMaterial You',
        lightAccent: 0xff111111,
        darkId: 'kDMaterial Dark',
        darkAccent: 0xff123456,
      );

      final ThemePreferences merged = mergeAccountTheme(
        account: account,
        local: local,
        owned: const <String>{},
        legacyThemes: const <String>{},
      );

      expect(merged.light.themeId, 'kLFrost White');
      expect(merged.light.accentColorValue, 0xffe57697);
    });
  });
}
