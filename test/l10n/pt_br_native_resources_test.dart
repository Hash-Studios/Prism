import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const androidDefaultPath = 'android/app/src/main/res/values/strings.xml';
  const androidPortuguesePath = 'android/app/src/main/res/values-pt-rBR/strings.xml';
  const xcstringsPath = 'ios/Runner/Localizable.xcstrings';
  const infoPlistPath = 'ios/Runner/pt-BR.lproj/InfoPlist.strings';
  const projectPath = 'ios/Runner.xcodeproj/project.pbxproj';

  Map<String, String> androidStrings(String path) {
    final xml = File(path).readAsStringSync();
    return Map<String, String>.fromEntries(
      RegExp(
        r'<string name="([^"]+)">(.*?)</string>',
        dotAll: true,
      ).allMatches(xml).map((match) => MapEntry(match.group(1)!, match.group(2)!)),
    );
  }

  List<String> placeholders(String value) =>
      RegExp(r'%\d+\$[a-zA-Z@]').allMatches(value).map((match) => match.group(0)!).toList()..sort();

  test('Android pt-BR resources have exact default key and placeholder parity', () {
    final defaults = androidStrings(androidDefaultPath);
    final portuguese = androidStrings(androidPortuguesePath);

    expect(portuguese.keys.toSet(), defaults.keys.toSet());
    expect(portuguese['app_name'], 'Prism');
    for (final key in defaults.keys) {
      expect(portuguese[key]!.trim(), isNotEmpty, reason: key);
      expect(placeholders(portuguese[key]!), placeholders(defaults[key]!), reason: key);
    }
  });

  test('Android pt-BR quoted notification titles preserve escaped quotes in XML', () {
    final portuguese = androidStrings(androidPortuguesePath);

    expect(
      portuguese['notif_push_wall_approved_for_artist_body'],
      r'\"%1$s\" foi aprovado e agora está visível para todos.',
    );
    expect(
      portuguese['notif_push_wall_live_for_followers_body'],
      r'\"%1$s\" já está no ar no Prism.',
    );
    expect(
      portuguese['notif_push_wall_approved_for_admin_body'],
      r'\"%1$s\", de %2$s, já está no ar.',
    );
  });

  test('iOS strings have translated pt-BR values and matching placeholders', () {
    final catalog = jsonDecode(File(xcstringsPath).readAsStringSync()) as Map<String, dynamic>;
    final strings = catalog['strings'] as Map<String, dynamic>;

    for (final entry in strings.entries) {
      final localizations = (entry.value as Map<String, dynamic>)['localizations'] as Map<String, dynamic>;
      final english =
          ((localizations['en'] as Map<String, dynamic>)['stringUnit'] as Map<String, dynamic>)['value'] as String;
      final portugueseLocalization = localizations['pt-BR'] as Map<String, dynamic>?;
      expect(portugueseLocalization, isNotNull, reason: entry.key);
      final portugueseUnit = portugueseLocalization!['stringUnit'] as Map<String, dynamic>?;
      expect(portugueseUnit, isNotNull, reason: entry.key);
      expect(portugueseUnit!['state'], 'translated', reason: entry.key);
      final translated = portugueseUnit['value'] as String?;
      expect(translated, isNotNull, reason: entry.key);
      expect(translated!.trim(), isNotEmpty, reason: entry.key);
      expect(placeholders(translated), placeholders(english), reason: entry.key);
    }
  });

  test('iOS pt-BR permission descriptions are present and wired into Xcode', () {
    final infoPlist = File(infoPlistPath).readAsStringSync();
    const descriptionKeys = <String>[
      'NSPhotoLibraryUsageDescription',
      'NSPhotoLibraryAddUsageDescription',
      'NSCameraUsageDescription',
    ];
    for (final key in descriptionKeys) {
      final value = RegExp('"$key"\\s*=\\s*"([^"]+)";').firstMatch(infoPlist)?.group(1);
      expect(value, isNotNull, reason: key);
      expect(value!.trim(), isNotEmpty, reason: key);
    }

    final project = File(projectPath).readAsStringSync();
    expect(project, contains('"pt-BR",'));
    expect(project, contains('pt-BR.lproj/InfoPlist.strings'));
    expect(project, contains('/* pt-BR */'));
    expect(project, contains('InfoPlist.strings in Resources'));
    expect(project, contains('Localizable.xcstrings in Resources'));
  });
}
