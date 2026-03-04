import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: dart run tool/validate_find_unused_allowlist.dart <report-json-path> <allowlist-json-path>');
    exitCode = 2;
    return;
  }

  final String reportPath = args[0];
  final String allowlistPath = args[1];

  final _Report report = _readReport(reportPath);
  final _Allowlist allowlist = _readAllowlist(allowlistPath);

  final Set<String> extraUnreachable = report.unreachable.difference(allowlist.unreachable);
  final Set<String> staleUnreachable = allowlist.unreachable.difference(report.unreachable);

  final Map<String, Set<String>> extraSymbols = <String, Set<String>>{};
  final Map<String, Set<String>> staleSymbols = <String, Set<String>>{};

  for (final MapEntry<String, Set<String>> entry in report.unusedSymbols.entries) {
    final Set<String> allowed = allowlist.unusedSymbols[entry.key] ?? <String>{};
    final Set<String> diff = entry.value.difference(allowed);
    if (diff.isNotEmpty) {
      extraSymbols[entry.key] = diff;
    }
  }

  for (final MapEntry<String, Set<String>> entry in allowlist.unusedSymbols.entries) {
    final Set<String> actual = report.unusedSymbols[entry.key] ?? <String>{};
    final Set<String> diff = entry.value.difference(actual);
    if (diff.isNotEmpty) {
      staleSymbols[entry.key] = diff;
    }
  }

  final bool hasExtras = extraUnreachable.isNotEmpty || extraSymbols.isNotEmpty;
  final bool hasStale = staleUnreachable.isNotEmpty || staleSymbols.isNotEmpty;

  stdout.writeln('find-unused-ci summary:');
  stdout.writeln('  unreachable files: ${report.unreachable.length}');
  stdout.writeln('  unused public symbols: ${report.unusedSymbolCount}');

  if (hasExtras) {
    stdout.writeln('\nNew dead code not in allowlist:');
    if (extraUnreachable.isNotEmpty) {
      stdout.writeln('  unreachable files:');
      for (final String file in extraUnreachable.toList()..sort()) {
        stdout.writeln('    - $file');
      }
    }
    if (extraSymbols.isNotEmpty) {
      stdout.writeln('  unused symbols:');
      final List<String> files = extraSymbols.keys.toList()..sort();
      for (final String file in files) {
        final List<String> symbols = extraSymbols[file]!.toList()..sort();
        stdout.writeln('    - $file');
        for (final String symbol in symbols) {
          stdout.writeln('      * $symbol');
        }
      }
    }
  }

  if (hasStale) {
    stdout.writeln('\nAllowlist entries now stale (can be removed):');
    if (staleUnreachable.isNotEmpty) {
      stdout.writeln('  unreachable files:');
      for (final String file in staleUnreachable.toList()..sort()) {
        stdout.writeln('    - $file');
      }
    }
    if (staleSymbols.isNotEmpty) {
      stdout.writeln('  unused symbols:');
      final List<String> files = staleSymbols.keys.toList()..sort();
      for (final String file in files) {
        final List<String> symbols = staleSymbols[file]!.toList()..sort();
        stdout.writeln('    - $file');
        for (final String symbol in symbols) {
          stdout.writeln('      * $symbol');
        }
      }
    }
  }

  if (hasExtras || hasStale) {
    exitCode = 1;
    return;
  }

  stdout.writeln('\nAllowlist matches current report.');
}

_Report _readReport(String path) {
  final String raw = File(path).readAsStringSync();
  final int start = raw.indexOf('{');
  final int end = raw.lastIndexOf('}');
  if (start < 0 || end < start) {
    throw FormatException('Could not locate JSON object in report: $path');
  }
  final String jsonPayload = raw.substring(start, end + 1);
  final Map<String, dynamic> decoded = json.decode(jsonPayload) as Map<String, dynamic>;
  return _Report.fromJson(decoded);
}

_Allowlist _readAllowlist(String path) {
  final Map<String, dynamic> decoded = json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return _Allowlist.fromJson(decoded);
}

class _Report {
  _Report({required this.unreachable, required this.unusedSymbols});

  factory _Report.fromJson(Map<String, dynamic> jsonMap) {
    final List<dynamic> unreachableRaw = jsonMap['unreachable_files'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic> unusedRaw = jsonMap['unused_symbols'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return _Report(
      unreachable: unreachableRaw.map((dynamic e) => e.toString()).toSet(),
      unusedSymbols: unusedRaw.map(
        (String file, dynamic symbols) => MapEntry<String, Set<String>>(
          file,
          (symbols as List<dynamic>? ?? <dynamic>[]).map((dynamic e) => e.toString()).toSet(),
        ),
      ),
    );
  }

  final Set<String> unreachable;
  final Map<String, Set<String>> unusedSymbols;

  int get unusedSymbolCount =>
      unusedSymbols.values.fold<int>(0, (int sum, Set<String> current) => sum + current.length);
}

class _Allowlist {
  _Allowlist({required this.unreachable, required this.unusedSymbols});

  factory _Allowlist.fromJson(Map<String, dynamic> jsonMap) {
    final List<dynamic> unreachableRaw = jsonMap['unreachable_files'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic> unusedRaw = jsonMap['unused_symbols'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return _Allowlist(
      unreachable: unreachableRaw.map((dynamic e) => e.toString()).toSet(),
      unusedSymbols: unusedRaw.map(
        (String file, dynamic symbols) => MapEntry<String, Set<String>>(
          file,
          (symbols as List<dynamic>? ?? <dynamic>[]).map((dynamic e) => e.toString()).toSet(),
        ),
      ),
    );
  }

  final Set<String> unreachable;
  final Map<String, Set<String>> unusedSymbols;
}
