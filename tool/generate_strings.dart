import 'dart:collection';
import 'dart:io';

const String _defaultXmlPath = 'android/app/src/main/res/values/strings.xml';
const String _defaultDartPath = 'lib/core/l10n/app_strings.g.dart';
const String _defaultIosPath = 'ios/Runner/Base.lproj/Localizable.strings';

void main(List<String> args) {
  final String xmlPath = args.isNotEmpty ? args.first : _defaultXmlPath;
  final String dartPath = args.length > 1 ? args[1] : _defaultDartPath;
  final String iosPath = args.length > 2 ? args[2] : _defaultIosPath;

  final LinkedHashMap<String, String> entries = _loadXml(xmlPath);
  if (entries.isEmpty) {
    stderr.writeln('No entries found in $xmlPath');
    exitCode = 1;
    return;
  }

  _writeDart(dartPath, entries);
  _writeIos(iosPath, entries);

  stdout.writeln('Generated ${entries.length} strings:');
  stdout.writeln('  Dart → $dartPath');
  stdout.writeln('  iOS  → $iosPath');
}

// ---------------------------------------------------------------------------
// XML parsing
// ---------------------------------------------------------------------------

final RegExp _entryRe = RegExp(r'<string name="([^"]+)">(.*?)</string>', dotAll: true);

LinkedHashMap<String, String> _loadXml(String path) {
  final LinkedHashMap<String, String> result = LinkedHashMap<String, String>();
  final File file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('strings.xml not found: $path');
    return result;
  }
  final String content = file.readAsStringSync();
  for (final RegExpMatch m in _entryRe.allMatches(content)) {
    result[m.group(1)!] = _xmlUnescape(m.group(2)!);
  }
  return result;
}

String _xmlUnescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'");

// ---------------------------------------------------------------------------
// Dart generation
// ---------------------------------------------------------------------------

void _writeDart(String path, LinkedHashMap<String, String> entries) {
  final StringBuffer buf = StringBuffer();
  buf.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.');
  buf.writeln('//');
  buf.writeln('// Run: dart run tool/generate_strings.dart');
  buf.writeln();
  buf.writeln('// ignore_for_file: lines_longer_than_80_chars');
  buf.writeln();
  buf.writeln('class AppStrings {');
  buf.writeln('  AppStrings._();');
  buf.writeln();
  for (final MapEntry<String, String> e in entries.entries) {
    final String dartKey = _snakeToCamel(e.key);
    final String escaped = _dartEscape(e.value);
    buf.writeln("  static const String $dartKey = '$escaped';");
  }
  buf.writeln('}');

  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buf.toString());
}

String _dartEscape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('\$', '\\\$')
    .replaceAll("'", "\\'");

// ---------------------------------------------------------------------------
// iOS Localizable.strings generation
// ---------------------------------------------------------------------------

void _writeIos(String path, LinkedHashMap<String, String> entries) {
  final StringBuffer buf = StringBuffer();
  buf.writeln('/* GENERATED CODE - DO NOT MODIFY BY HAND. */');
  buf.writeln('/* Run: dart run tool/generate_strings.dart */');
  buf.writeln();
  for (final MapEntry<String, String> e in entries.entries) {
    final String escaped = _iosEscape(e.value);
    buf.writeln('"${e.key}" = "$escaped";');
  }

  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buf.toString());
}

String _iosEscape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\n', '\\n');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _snakeToCamel(String key) {
  final List<String> parts = key.split('_').where((String p) => p.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) return key;
  final String first = parts.first;
  if (parts.length == 1) return first;
  final String rest = parts.skip(1).map((String p) => p[0].toUpperCase() + p.substring(1)).join();
  return '$first$rest';
}
