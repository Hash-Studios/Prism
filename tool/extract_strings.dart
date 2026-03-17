import 'dart:collection';
import 'dart:io';

const String _defaultXmlPath = 'android/app/src/main/res/values/strings.xml';
const String _defaultLibPath = 'lib';

/// Extraction patterns: (label, regex for single-quoted, regex for double-quoted)
final List<(String, RegExp, RegExp)> _patterns = [
  // Text('...') / Text("...")
  (
    'Text',
    RegExp(r"""Text\s*\(\s*'([^'$\\\n]{2,})'\s*[,)]"""),
    RegExp(r'''Text\s*\(\s*"([^"$\\\n]{2,})"\s*[,)]'''),
  ),
  // Named UI parameters
  (
    'label',
    RegExp(r"""(?<![A-Za-z])label\s*:\s*'([^'$\\\n]{2,})'"""),
    RegExp(r'''(?<![A-Za-z])label\s*:\s*"([^"$\\\n]{2,})"'''),
  ),
  (
    'title',
    RegExp(r"""(?<![A-Za-z])title\s*:\s*'([^'$\\\n]{2,})'"""),
    RegExp(r'''(?<![A-Za-z])title\s*:\s*"([^"$\\\n]{2,})"'''),
  ),
  (
    'hintText',
    RegExp(r"""hintText\s*:\s*'([^'$\\\n]{2,})'"""),
    RegExp(r'''hintText\s*:\s*"([^"$\\\n]{2,})"'''),
  ),
  (
    'labelText',
    RegExp(r"""labelText\s*:\s*'([^'$\\\n]{2,})'"""),
    RegExp(r'''labelText\s*:\s*"([^"$\\\n]{2,})"'''),
  ),
  (
    'tooltip',
    RegExp(r"""tooltip\s*:\s*'([^'$\\\n]{2,})'"""),
    RegExp(r'''tooltip\s*:\s*"([^"$\\\n]{2,})"'''),
  ),
  (
    'semanticsLabel',
    RegExp(r"""semanticsLabel\s*:\s*'([^'$\\\n]{2,})'"""),
    RegExp(r'''semanticsLabel\s*:\s*"([^"$\\\n]{2,})"'''),
  ),
  (
    'placeholderText',
    RegExp(r"""placeholderText\s*:\s*'([^'$\\\n]{2,})'"""),
    RegExp(r'''placeholderText\s*:\s*"([^"$\\\n]{2,})"'''),
  ),
  (
    'buttonText',
    RegExp(r"""buttonText\s*:\s*'([^'$\\\n]{2,})'"""),
    RegExp(r'''buttonText\s*:\s*"([^"$\\\n]{2,})"'''),
  ),
];

void main(List<String> args) {
  final String xmlPath = args.isNotEmpty ? args.first : _defaultXmlPath;
  final String libPath = args.length > 1 ? args[1] : _defaultLibPath;

  // Load existing strings.xml preserving order
  final LinkedHashMap<String, String> existing = _loadXml(xmlPath);

  // Build reverse map: value → key (for dedup against existing)
  final Map<String, String> valueToKey = <String, String>{};
  for (final MapEntry<String, String> entry in existing.entries) {
    valueToKey[entry.value] = entry.key;
  }

  // Scan lib/ for UI strings
  final List<String> extracted = _scanDirectory(Directory(libPath));

  // Merge: add new entries, update changed values for same key is not done
  // (key is preserved, value updates are manual for safety).
  // Only new strings (not already in valueToKey) are added.
  int added = 0;
  for (final String value in extracted) {
    if (valueToKey.containsKey(value)) continue;
    final String key = _generateKey(value, existing.keys.toSet());
    existing[key] = value;
    valueToKey[value] = key;
    added++;
  }

  _writeXml(xmlPath, existing);
  stdout.writeln('Scanned ${extracted.length} unique strings, added $added new entries to $xmlPath');
}

// ---------------------------------------------------------------------------
// XML I/O
// ---------------------------------------------------------------------------

final RegExp _entryRe = RegExp(r'<string name="([^"]+)">(.*?)</string>', dotAll: true);

LinkedHashMap<String, String> _loadXml(String path) {
  final LinkedHashMap<String, String> result = LinkedHashMap<String, String>();
  final File file = File(path);
  if (!file.existsSync()) return result;
  final String content = file.readAsStringSync();
  for (final RegExpMatch m in _entryRe.allMatches(content)) {
    result[m.group(1)!] = _xmlUnescape(m.group(2)!);
  }
  return result;
}

void _writeXml(String path, LinkedHashMap<String, String> entries) {
  final StringBuffer buf = StringBuffer();
  buf.writeln('<?xml version="1.0" encoding="utf-8"?>');
  buf.writeln('<resources>');
  for (final MapEntry<String, String> e in entries.entries) {
    buf.writeln('    <string name="${e.key}">${_xmlEscape(e.value)}</string>');
  }
  buf.write('</resources>');
  File(path).writeAsStringSync(buf.toString());
}

String _xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _xmlUnescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'");

// ---------------------------------------------------------------------------
// Directory scanning
// ---------------------------------------------------------------------------

List<String> _scanDirectory(Directory dir) {
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: ${dir.path}');
    return const <String>[];
  }

  final List<String> results = <String>[];
  final Iterable<File> dartFiles = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) {
        final String name = f.uri.pathSegments.last;
        return name.endsWith('.dart') &&
            !name.endsWith('.g.dart') &&
            !name.endsWith('.freezed.dart') &&
            !name.endsWith('.gr.dart');
      });

  for (final File file in dartFiles) {
    String content;
    try {
      content = file.readAsStringSync();
    } catch (_) {
      continue;
    }
    results.addAll(_extractStrings(content));
  }

  // Deduplicate while preserving first-seen order
  final Set<String> seen = <String>{};
  return results.where(seen.add).toList(growable: false);
}

// ---------------------------------------------------------------------------
// String extraction
// ---------------------------------------------------------------------------

List<String> _extractStrings(String content) {
  final List<String> results = <String>[];
  for (final (_, RegExp single, RegExp double_) in _patterns) {
    for (final RegExpMatch m in single.allMatches(content)) {
      final String v = m.group(1)!.trim();
      if (!_shouldExclude(v)) results.add(v);
    }
    for (final RegExpMatch m in double_.allMatches(content)) {
      final String v = m.group(1)!.trim();
      if (!_shouldExclude(v)) results.add(v);
    }
  }
  return results;
}

bool _shouldExclude(String value) {
  if (value.length < 2) return true;
  // URLs
  if (value.contains('://')) return true;
  if (value.startsWith('www.')) return true;
  // File paths / asset keys
  if (value.startsWith('assets/')) return true;
  if (value.startsWith('/')) return true;
  if (RegExp(r'\.(png|jpg|jpeg|svg|gif|webp|json|yaml|xml|dart|js)$').hasMatch(value)) return true;
  // Only digits, whitespace, or punctuation — no letters
  if (!RegExp(r'[A-Za-z]').hasMatch(value)) return true;
  // Looks like a programmatic key: all lowercase + underscores + digits, no spaces
  // e.g. 'screen_view', 'content_type' — analytics / Firebase keys
  if (RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value) && value.contains('_')) return true;
  // Package names / import paths
  if (value.startsWith('package:')) return true;
  // Regex patterns
  if (value.contains(r'\d') || value.contains(r'\w') || value.contains(r'\s')) return true;
  return false;
}

// ---------------------------------------------------------------------------
// Key generation
// ---------------------------------------------------------------------------

String _generateKey(String value, Set<String> existingKeys) {
  String key = _toSnakeCase(value);
  if (key.isEmpty) key = 'string';
  if (!existingKeys.contains(key)) return key;
  int i = 2;
  while (existingKeys.contains('${key}_$i')) {
    i++;
  }
  return '${key}_$i';
}

String _toSnakeCase(String value) {
  // Lowercase, replace runs of non-alphanumeric chars with single underscore
  String result = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  // Strip leading/trailing underscores
  result = result.replaceAll(RegExp(r'^_+|_+$'), '');
  // Truncate to 50 chars at a word boundary
  if (result.length > 50) {
    result = result.substring(0, 50);
    final int lastUnderscore = result.lastIndexOf('_');
    if (lastUnderscore > 10) result = result.substring(0, lastUnderscore);
  }
  return result;
}
