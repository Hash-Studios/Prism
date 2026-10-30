import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _androidEnglishPath = 'android/app/src/main/res/values/strings.xml';
const String _androidSpanishPath = 'android/app/src/main/res/values-es/strings.xml';
const String _iosCatalogPath = 'ios/Runner/Localizable.xcstrings';
const String _iosEnglishInfoPath = 'ios/Runner/en.lproj/InfoPlist.strings';
const String _iosSpanishInfoPath = 'ios/Runner/es.lproj/InfoPlist.strings';
const String _iosProjectPath = 'ios/Runner.xcodeproj/project.pbxproj';

void main() {
  test('gift notification limits the Spanish benefit to premium collections and wallpapers', () {
    const String expected = 'Las colecciones prémium y los fondos prémium estarán disponibles hasta mañana.';
    final Map<String, String> android = _readAndroidStrings(_androidSpanishPath);
    final Map<String, Object?> catalog = jsonDecode(File(_iosCatalogPath).readAsStringSync()) as Map<String, Object?>;
    final Map<String, Object?> strings = catalog['strings']! as Map<String, Object?>;
    final Map<String, Object?> giftBody = strings['notif_push_gift_received_body']! as Map<String, Object?>;
    final Map<String, Object?> localizations = giftBody['localizations']! as Map<String, Object?>;

    expect(android['notif_push_gift_received_body'], expected);
    expect(_xcstringsValue(localizations, 'es', 'notif_push_gift_received_body'), expected);
  });

  test('Android Spanish resources cover the English keys and format arguments', () {
    final Map<String, String> english = _readAndroidStrings(_androidEnglishPath);
    final Map<String, String> spanish = _readAndroidStrings(_androidSpanishPath);

    expect(english, hasLength(70));
    expect(spanish.keys.toSet(), english.keys.toSet());

    for (final MapEntry<String, String> entry in english.entries) {
      final String translated = spanish[entry.key]!;
      expect(translated.trim(), isNotEmpty, reason: 'Android resource ${entry.key} is blank in Spanish');
      expect(
        _formatArguments(translated),
        _formatArguments(entry.value),
        reason: 'Android resource ${entry.key} has different printf arguments in Spanish',
      );
    }
  });

  test('iOS Spanish catalog has all translated English records and matching placeholders', () {
    final Map<String, Object?> catalog = jsonDecode(File(_iosCatalogPath).readAsStringSync()) as Map<String, Object?>;
    final Map<String, Object?> strings = catalog['strings']! as Map<String, Object?>;

    expect(catalog['sourceLanguage'], 'en');
    expect(strings, hasLength(62));

    for (final MapEntry<String, Object?> entry in strings.entries) {
      final Map<String, Object?> record = entry.value! as Map<String, Object?>;
      final Map<String, Object?> localizations = record['localizations']! as Map<String, Object?>;
      final String english = _xcstringsValue(localizations, 'en', entry.key);
      final String spanish = _xcstringsValue(localizations, 'es', entry.key);

      expect(spanish.trim(), isNotEmpty, reason: 'iOS resource ${entry.key} is blank in Spanish');
      expect(
        _formatArguments(spanish),
        _formatArguments(english),
        reason: 'iOS resource ${entry.key} has different format arguments in Spanish',
      );
    }
  });

  test('iOS Spanish InfoPlist permissions match English and are registered with Xcode', () {
    final Map<String, String> english = _readInfoPlistStrings(_iosEnglishInfoPath);
    final Map<String, String> spanish = _readInfoPlistStrings(_iosSpanishInfoPath);
    const Set<String> expectedPermissionKeys = <String>{
      'NSCameraUsageDescription',
      'NSMotionUsageDescription',
      'NSPhotoLibraryAddUsageDescription',
      'NSPhotoLibraryUsageDescription',
    };

    expect(english.keys.toSet(), expectedPermissionKeys);
    expect(spanish.keys.toSet(), expectedPermissionKeys);
    for (final String key in expectedPermissionKeys) {
      expect(english[key]!.trim(), isNotEmpty, reason: 'English InfoPlist value $key is blank');
      expect(spanish[key]!.trim(), isNotEmpty, reason: 'Spanish InfoPlist value $key is blank');
    }

    final String project = File(_iosProjectPath).readAsStringSync();
    expect(project, contains('path = es.lproj/InfoPlist.strings;'));

    final RegExpMatch? knownRegions = RegExp(r'knownRegions\s*=\s*\(([^)]*)\);', dotAll: true).firstMatch(project);
    expect(knownRegions, isNotNull, reason: 'Xcode project has no knownRegions list');
    expect(RegExp(r'\bes\b').hasMatch(knownRegions!.group(1)!), isTrue, reason: 'Xcode does not register Spanish');
  });
}

Map<String, String> _readAndroidStrings(String path) {
  final String xml = File(path).readAsStringSync();
  final Iterable<RegExpMatch> matches = RegExp(
    r'<string\s+name="([^"]+)"[^>]*>(.*?)</string>',
    dotAll: true,
  ).allMatches(xml);
  final Map<String, String> strings = <String, String>{};
  for (final RegExpMatch match in matches) {
    final String key = match.group(1)!;
    expect(strings.containsKey(key), isFalse, reason: 'Duplicate Android resource $key in $path');
    strings[key] = match.group(2)!;
  }
  expect(strings, isNotEmpty, reason: 'No Android strings found in $path');
  return strings;
}

Map<String, String> _readInfoPlistStrings(String path) {
  final String contents = File(path).readAsStringSync();
  final Iterable<RegExpMatch> matches = RegExp(
    r'^\s*"([^"]+)"\s*=\s*"(.*)";\s*$',
    multiLine: true,
  ).allMatches(contents);
  final Map<String, String> strings = <String, String>{};
  for (final RegExpMatch match in matches) {
    final String key = match.group(1)!;
    expect(strings.containsKey(key), isFalse, reason: 'Duplicate InfoPlist key $key in $path');
    strings[key] = match.group(2)!;
  }
  expect(strings, isNotEmpty, reason: 'No InfoPlist strings found in $path');
  return strings;
}

String _xcstringsValue(Map<String, Object?> localizations, String locale, String key) {
  final Map<String, Object?>? localization = localizations[locale] as Map<String, Object?>?;
  expect(localization, isNotNull, reason: 'iOS resource $key has no $locale localization');
  final Map<String, Object?>? unit = localization!['stringUnit'] as Map<String, Object?>?;
  expect(unit, isNotNull, reason: 'iOS resource $key has no $locale string unit');
  expect(unit!['state'], 'translated', reason: 'iOS resource $key is not marked translated in $locale');
  return unit['value'] as String;
}

List<String> _formatArguments(String value) {
  return RegExp(r'%(?:\d+\$)?[-+#0 ]*\d*(?:\.\d+)?[sdifouxXc@]').allMatches(value).map((RegExpMatch match) {
    return match.group(0)!;
  }).toList()..sort();
}
