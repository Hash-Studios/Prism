// ignore_for_file: avoid_print
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

/// Package name used for resolving package: URIs.
const String _packageName = 'Prism';

/// Suffixes that identify generated/synthetic Dart files.
const List<String> _generatedSuffixes = <String>[
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
];

// ---------------------------------------------------------------------------
// Regex patterns
// ---------------------------------------------------------------------------

/// Matches `import '...'` or `import "..."` (handles conditional imports –
/// we only follow the primary path, i.e., the first URI captured).
final RegExp _importRe = RegExp(
  r"""^import\s+['"]([^'"]+)['"]""",
  multiLine: true,
);

/// Matches `export '...'` or `export "..."`.
final RegExp _exportRe = RegExp(
  r"""^export\s+['"]([^'"]+)['"]""",
  multiLine: true,
);

/// Matches `part '...'` — note: does NOT match `part of '...'` because
/// `part of` has a word after `part`, not a quote character.
final RegExp _partRe = RegExp(r"""^part\s+['"]([^'"]+)['"]""", multiLine: true);

/// Matches top-level type declarations (class, mixin, enum, extension, typedef).
final RegExp _typeDeclRe = RegExp(
  r"""^\s*(?:(?:abstract|sealed|final|base|interface)\s+)*(?:mixin\s+class|class|mixin|enum|extension(?:\s+type)?|typedef)\s+([A-Za-z][a-zA-Z0-9_]*)""",
  multiLine: true,
);

/// Matches top-level function/getter declarations with common return types.
final RegExp _funcDeclRe = RegExp(
  r"""^(?:Future|Stream|List|Map|Set|String|int|double|bool|void|Object|dynamic|num|Uint8List|Widget|Color|ThemeData)[<\w,\s>?\[\]]*\s+(?:get\s+)?([a-z][a-zA-Z0-9_]*)\s*(?:\(|=>|\{)""",
  multiLine: true,
);

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main(List<String> args) {
  final bool htmlMode = args.contains('--html');
  final bool jsonMode = args.contains('--json');
  final bool failOnFindings = args.contains('--fail-on-findings');

  final String projectRoot = Directory.current.path;
  final String libDir = '$projectRoot/lib';

  if (!File('$projectRoot/pubspec.yaml').existsSync()) {
    stderr.writeln(
      'Error: pubspec.yaml not found. Run this script from the project root.',
    );
    exitCode = 1;
    return;
  }

  // ── Phase A: Build import graph ─────────────────────────────────────────
  if (!jsonMode) stdout.writeln('Building import graph…');
  final Map<String, Set<String>> graph = _buildImportGraph(libDir);
  final Set<String> allFiles = graph.keys.toSet();

  // ── Phase B: BFS from entry point ───────────────────────────────────────
  final String entryPoint = '$libDir/main.dart';
  if (!File(entryPoint).existsSync()) {
    stderr.writeln('Entry point not found: $entryPoint');
    exitCode = 1;
    return;
  }
  final Set<String> reachable = _bfsReachable(entryPoint, graph);

  // ── Phase C: Classify unreachable files ─────────────────────────────────
  final List<String> unreachable = _findUnreachable(allFiles, reachable)
    ..sort();

  // ── Phase D: Unused public symbols in reachable files ───────────────────
  if (!jsonMode) stdout.writeln('Scanning for unused public symbols…');
  final Map<String, List<String>> unusedSymbols = _findUnusedPublicSymbols(
    reachable,
    allFiles,
  );

  // ── Stats ────────────────────────────────────────────────────────────────
  final int generatedCount = allFiles.where(_isGenerated).length;
  final int sourceCount = allFiles.length - generatedCount;

  // ── Output ───────────────────────────────────────────────────────────────
  if (jsonMode) {
    _outputJson(
      sourceCount: sourceCount,
      generatedCount: generatedCount,
      entryPoint: _rel(entryPoint, projectRoot),
      unreachable: unreachable.map((f) => _rel(f, projectRoot)).toList(),
      unusedSymbols: unusedSymbols.map(
        (k, v) => MapEntry(_rel(k, projectRoot), v),
      ),
    );
  } else {
    _outputTerminal(
      sourceCount: sourceCount,
      generatedCount: generatedCount,
      entryPoint: _rel(entryPoint, projectRoot),
      unreachable: unreachable,
      unusedSymbols: unusedSymbols,
      projectRoot: projectRoot,
    );
  }

  if (htmlMode) {
    final String reportPath = '$projectRoot/dead_code_report.html';
    _generateHtml(
      sourceCount: sourceCount,
      generatedCount: generatedCount,
      unreachable: unreachable,
      unusedSymbols: unusedSymbols,
      projectRoot: projectRoot,
      outputPath: reportPath,
    );
    if (!jsonMode) stdout.writeln('HTML report: dead_code_report.html');
    if (Platform.isMacOS) Process.run('open', <String>[reportPath]);
  }

  stdout.writeln('\n=== Done ===');

  if (failOnFindings && (unreachable.isNotEmpty || unusedSymbols.isNotEmpty)) {
    exitCode = 1;
  }
}

// ---------------------------------------------------------------------------
// Phase A — import graph
// ---------------------------------------------------------------------------

Map<String, Set<String>> _buildImportGraph(String libDir) {
  final Map<String, Set<String>> graph = <String, Set<String>>{};

  final List<File> dartFiles = Directory(libDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  // Register every file in the graph (so BFS can visit them).
  for (final File f in dartFiles) {
    graph[f.path] = <String>{};
  }

  for (final File file in dartFiles) {
    final String content;
    try {
      content = file.readAsStringSync();
    } catch (_) {
      continue;
    }
    final String filePath = file.path;
    final String fileDir = file.parent.path;

    void addEdge(String uri) {
      final String? resolved = _resolveUri(uri, fileDir, libDir);
      if (resolved != null && graph.containsKey(resolved)) {
        graph[filePath]!.add(resolved);
      }
    }

    for (final Match m in _importRe.allMatches(content)) {
      addEdge(m.group(1)!);
    }
    for (final Match m in _exportRe.allMatches(content)) {
      addEdge(m.group(1)!);
    }
    for (final Match m in _partRe.allMatches(content)) {
      final String uri = m.group(1)!;
      final String? resolved = _resolveUri(uri, fileDir, libDir);
      if (resolved != null && graph.containsKey(resolved)) {
        // Parent → part child
        graph[filePath]!.add(resolved);
        // Part child → parent (so the child is reachable from the parent and vice-versa)
        graph[resolved]!.add(filePath);
      }
    }
  }

  return graph;
}

String? _resolveUri(String uri, String fileDir, String libDir) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    final String rest = uri.substring('package:'.length);
    final int slash = rest.indexOf('/');
    if (slash < 0) return null;
    final String pkg = rest.substring(0, slash);
    if (pkg != _packageName) return null;
    return '$libDir/${rest.substring(slash + 1)}';
  }
  // Relative path
  try {
    return Uri.directory(fileDir).resolve(uri).toFilePath();
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Phase B — BFS
// ---------------------------------------------------------------------------

Set<String> _bfsReachable(String entryPoint, Map<String, Set<String>> graph) {
  final Set<String> visited = <String>{};
  final Queue<String> queue = Queue<String>()..add(entryPoint);
  while (queue.isNotEmpty) {
    final String node = queue.removeFirst();
    if (!visited.add(node)) continue;
    for (final String dep in graph[node] ?? const <String>{}) {
      if (!visited.contains(dep)) queue.add(dep);
    }
  }
  return visited;
}

// ---------------------------------------------------------------------------
// Phase C — unreachable files
// ---------------------------------------------------------------------------

List<String> _findUnreachable(Set<String> allFiles, Set<String> reachable) =>
    allFiles
        .where((String f) => !reachable.contains(f) && !_isGenerated(f))
        .toList();

bool _isGenerated(String path) {
  for (final String suffix in _generatedSuffixes) {
    if (path.endsWith(suffix)) return true;
  }
  try {
    // Check first 120 bytes for generated code header.
    final RandomAccessFile raf = File(path).openSync();
    final List<int> bytes = raf.readSync(120);
    raf.closeSync();
    final String header = String.fromCharCodes(bytes);
    if (header.contains('GENERATED CODE') || header.contains('generated by'))
      return true;
  } catch (_) {}
  return false;
}

// ---------------------------------------------------------------------------
// Phase D — unused public symbols
// ---------------------------------------------------------------------------

Map<String, List<String>> _findUnusedPublicSymbols(
  Set<String> reachable,
  Set<String> allFiles,
) {
  // Load all file contents once.
  final Map<String, String> contents = <String, String>{};
  for (final String f in allFiles) {
    try {
      contents[f] = File(f).readAsStringSync();
    } catch (_) {}
  }

  // Concatenated content of ALL files (used to check cross-file references).
  // We'll search per-file rather than building a mega-string to avoid RAM spike.
  final List<String> otherFiles = allFiles
      .toList(); // will skip defining file per symbol

  final Map<String, List<String>> result = <String, List<String>>{};

  for (final String file in reachable) {
    if (_isGenerated(file)) continue;
    final String? content = contents[file];
    if (content == null) continue;

    final List<String> symbols = _extractPublicSymbols(content);
    if (symbols.isEmpty) continue;

    final List<String> unused = <String>[];
    for (final String symbol in symbols) {
      // Count occurrences in all OTHER files.
      bool foundElsewhere = false;
      final RegExp symbolRe = RegExp('\\b${RegExp.escape(symbol)}\\b');
      for (final String other in otherFiles) {
        if (other == file) continue;
        final String? otherContent = contents[other];
        if (otherContent == null) continue;
        if (symbolRe.hasMatch(otherContent)) {
          foundElsewhere = true;
          break;
        }
      }
      if (!foundElsewhere) unused.add(symbol);
    }

    if (unused.isNotEmpty) result[file] = unused;
  }

  return result;
}

List<String> _extractPublicSymbols(String content) {
  final Set<String> symbols = <String>{};

  for (final Match m in _typeDeclRe.allMatches(content)) {
    final String name = m.group(1) ?? '';
    if (name.isEmpty || name.startsWith('_')) continue;
    symbols.add(name);
  }

  for (final Match m in _funcDeclRe.allMatches(content)) {
    final String name = m.group(1) ?? '';
    if (name.isEmpty || name.startsWith('_')) continue;
    symbols.add(name);
  }

  return symbols.toList();
}

// ---------------------------------------------------------------------------
// Output — terminal
// ---------------------------------------------------------------------------

void _outputTerminal({
  required int sourceCount,
  required int generatedCount,
  required String entryPoint,
  required List<String> unreachable,
  required Map<String, List<String>> unusedSymbols,
  required String projectRoot,
}) {
  stdout.writeln('\n=== Prism Dead Code Analysis ===');
  stdout.writeln(
    'Analysed $sourceCount source files ($generatedCount generated excluded).',
  );
  stdout.writeln('Entry point: $entryPoint');

  // ── Unreachable files ────────────────────────────────────────────────────
  final String uTitle = '── UNREACHABLE FILES (${unreachable.length}) ';
  stdout.writeln('\n$uTitle${'─' * (76 - uTitle.length)}');
  if (unreachable.isEmpty) {
    stdout.writeln('  (none — all files are reachable from main.dart)');
  } else {
    stdout.writeln(
      'Files never reached from main.dart via import/export/part chains.',
    );
    stdout.writeln();
    for (final String f in unreachable) {
      stdout.writeln('  ${_rel(f, projectRoot)}');
    }
  }

  // ── Unused public symbols ────────────────────────────────────────────────
  final int symbolCount = unusedSymbols.values.fold(
    0,
    (int s, List<String> l) => s + l.length,
  );
  final String sTitle = '── UNUSED PUBLIC SYMBOLS ($symbolCount) ';
  stdout.writeln('\n$sTitle${'─' * (76 - sTitle.length)}');
  if (unusedSymbols.isEmpty) {
    stdout.writeln('  (none detected)');
  } else {
    stdout.writeln(
      'Declared in reachable files, but never referenced elsewhere.',
    );
    stdout.writeln(
      'Note: DI/router-registered symbols may be false positives.',
    );
    stdout.writeln();
    for (final MapEntry<String, List<String>> entry in unusedSymbols.entries) {
      stdout.writeln('  ${_rel(entry.key, projectRoot)}');
      for (final String sym in entry.value) {
        stdout.writeln('    └─ $sym');
      }
      stdout.writeln();
    }
  }
}

// ---------------------------------------------------------------------------
// Output — JSON
// ---------------------------------------------------------------------------

void _outputJson({
  required int sourceCount,
  required int generatedCount,
  required String entryPoint,
  required List<String> unreachable,
  required Map<String, List<String>> unusedSymbols,
}) {
  final Map<String, Object> report = <String, Object>{
    'source_files': sourceCount,
    'generated_files': generatedCount,
    'entry_point': entryPoint,
    'unreachable_files': unreachable,
    'unused_symbols': unusedSymbols,
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}

// ---------------------------------------------------------------------------
// Output — HTML
// ---------------------------------------------------------------------------

void _generateHtml({
  required int sourceCount,
  required int generatedCount,
  required List<String> unreachable,
  required Map<String, List<String>> unusedSymbols,
  required String projectRoot,
  required String outputPath,
}) {
  final int unusedSymbolCount = unusedSymbols.values.fold(
    0,
    (int s, List<String> l) => s + l.length,
  );

  // Sort unreachable by line count desc for HTML (biggest impact first).
  final List<_FileInfo> unreachableInfo = unreachable.map((String f) {
    final int lines = _lineCount(f);
    return _FileInfo(path: _rel(f, projectRoot), lines: lines);
  }).toList()..sort((_FileInfo a, _FileInfo b) => b.lines.compareTo(a.lines));

  // Group unreachable by top lib folder.
  final Map<String, List<_FileInfo>> unreachableByFolder =
      <String, List<_FileInfo>>{};
  for (final _FileInfo info in unreachableInfo) {
    final String folder = _topFolder(info.path);
    (unreachableByFolder[folder] ??= <_FileInfo>[]).add(info);
  }

  // Group unused symbols by file.
  final List<MapEntry<String, List<String>>> sortedSymbols =
      unusedSymbols.entries
          .map(
            (MapEntry<String, List<String>> e) =>
                MapEntry<String, List<String>>(
                  _rel(e.key, projectRoot),
                  e.value,
                ),
          )
          .toList()
        ..sort(
          (
            MapEntry<String, List<String>> a,
            MapEntry<String, List<String>> b,
          ) => b.value.length.compareTo(a.value.length),
        );

  final StringBuffer html = StringBuffer();

  html.writeln('<!DOCTYPE html>');
  html.writeln('<html lang="en">');
  html.writeln('<head>');
  html.writeln('<meta charset="utf-8">');
  html.writeln(
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
  );
  html.writeln('<title>Prism Dead Code Report</title>');
  html.writeln('<style>');
  html.writeln(_htmlCss());
  html.writeln('</style>');
  html.writeln('</head>');
  html.writeln('<body>');

  html.writeln('<h1>Prism Dead Code Report</h1>');
  html.writeln(
    '<p class="subtitle">Generated ${DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ')}</p>',
  );

  // Stats cards
  html.writeln('<div class="stats">');
  html.writeln(_statCard('Source Files', '$sourceCount'));
  html.writeln(_statCard('Generated (excluded)', '$generatedCount'));
  html.writeln(
    _statCard(
      'Unreachable Files',
      '${unreachable.length}',
      warn: unreachable.isNotEmpty,
    ),
  );
  html.writeln(
    _statCard(
      'Unused Symbols',
      '$unusedSymbolCount',
      warn: unusedSymbolCount > 0,
    ),
  );
  html.writeln('</div>');

  // Known limitations notice
  html.writeln(
    '<details class="notice"><summary>Known limitations &amp; false-positive sources</summary>',
  );
  html.writeln('<ul>');
  html.writeln(
    '<li><strong>Unused public symbols</strong> may be false positives for <code>@injectable</code> classes and auto_route-registered screens.</li>',
  );
  html.writeln(
    '<li>Conditional imports (<code>if (dart.library.html)</code>) — only the primary URI path is followed.</li>',
  );
  html.writeln(
    '<li>Dynamic/reflective references (<code>Type.toString()</code>) are not detectable.</li>',
  );
  html.writeln(
    '<li>Symbols used only in <code>test/</code> appear unused if that directory is excluded from the scan.</li>',
  );
  html.writeln('</ul>');
  html.writeln('</details>');

  // ── Unreachable files section ────────────────────────────────────────────
  html.writeln('<h2>Unreachable Files (${unreachable.length})</h2>');
  if (unreachable.isEmpty) {
    html.writeln(
      '<p class="empty">All files are reachable from <code>lib/main.dart</code>.</p>',
    );
  } else {
    html.writeln(
      '<p class="hint">Files never reached from <code>lib/main.dart</code> via import / export / part chains. Sorted by line count (largest first).</p>',
    );
    for (final MapEntry<String, List<_FileInfo>> folderEntry
        in unreachableByFolder.entries) {
      html.writeln('<details open>');
      html.writeln(
        '<summary class="folder">${folderEntry.key} <span class="badge">${folderEntry.value.length}</span></summary>',
      );
      html.writeln('<table>');
      html.writeln(
        '<thead><tr><th>File</th><th class="num">Lines</th></tr></thead>',
      );
      html.writeln('<tbody>');
      for (final _FileInfo info in folderEntry.value) {
        html.writeln(
          '<tr><td class="path"><code>${info.path}</code></td><td class="num">${info.lines}</td></tr>',
        );
      }
      html.writeln('</tbody></table>');
      html.writeln('</details>');
    }
  }

  // ── Unused public symbols section ────────────────────────────────────────
  html.writeln('<h2>Unused Public Symbols ($unusedSymbolCount)</h2>');
  if (sortedSymbols.isEmpty) {
    html.writeln('<p class="empty">No unused public symbols detected.</p>');
  } else {
    html.writeln(
      '<p class="hint">Declared in reachable files, but never referenced in any other file. DI / router-registered symbols may be false positives.</p>',
    );
    for (final MapEntry<String, List<String>> entry in sortedSymbols) {
      html.writeln('<details open>');
      html.writeln(
        '<summary class="folder"><code>${entry.key}</code> <span class="badge">${entry.value.length}</span></summary>',
      );
      html.writeln('<ul class="symbols">');
      for (final String sym in entry.value) {
        html.writeln('<li><code>$sym</code></li>');
      }
      html.writeln('</ul>');
      html.writeln('</details>');
    }
  }

  html.writeln('<script>');
  html.writeln(_htmlJs());
  html.writeln('</script>');
  html.writeln('</body>');
  html.writeln('</html>');

  File(outputPath).writeAsStringSync(html.toString());
}

String _htmlCss() => """
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #0d1117; color: #c9d1d9; padding: 2rem;
    line-height: 1.6; max-width: 1100px; margin: 0 auto;
  }
  h1 { font-size: 1.8rem; color: #f0f6fc; margin-bottom: .25rem; }
  h2 { font-size: 1.25rem; color: #f0f6fc; margin: 2rem 0 .5rem; border-bottom: 1px solid #30363d; padding-bottom: .4rem; }
  .subtitle { color: #8b949e; font-size: .85rem; margin-bottom: 1.5rem; }
  .stats { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
  .stat-card {
    background: #161b22; border: 1px solid #30363d; border-radius: 8px;
    padding: .75rem 1.25rem; min-width: 140px;
  }
  .stat-card.warn { border-color: #f0883e; }
  .stat-card .label { font-size: .75rem; color: #8b949e; text-transform: uppercase; letter-spacing: .05em; }
  .stat-card .value { font-size: 1.6rem; font-weight: 700; color: #f0f6fc; }
  .stat-card.warn .value { color: #f0883e; }
  details { margin: .5rem 0; }
  details summary {
    cursor: pointer; padding: .5rem .75rem;
    background: #161b22; border: 1px solid #30363d; border-radius: 6px;
    user-select: none; list-style: none; display: flex; align-items: center; gap: .5rem;
  }
  details summary::-webkit-details-marker { display: none; }
  details summary::before { content: '▶'; font-size: .65rem; color: #8b949e; transition: transform .15s; }
  details[open] summary::before { transform: rotate(90deg); }
  details > *:not(summary) { margin: .25rem 0 .25rem 1rem; }
  .folder { font-size: .9rem; font-weight: 600; color: #79c0ff; }
  .badge {
    background: #30363d; color: #8b949e; border-radius: 10px;
    padding: .1rem .5rem; font-size: .75rem; margin-left: auto;
  }
  table { width: 100%; border-collapse: collapse; font-size: .85rem; }
  thead tr { border-bottom: 1px solid #30363d; }
  th { padding: .4rem .6rem; color: #8b949e; font-weight: 600; text-align: left; }
  td { padding: .35rem .6rem; border-bottom: 1px solid #21262d; }
  .path { word-break: break-all; }
  .num { text-align: right; width: 70px; color: #8b949e; }
  .symbols { padding-left: 1.5rem; }
  .symbols li { padding: .2rem 0; color: #a5d6ff; }
  code { font-family: 'SFMono-Regular', Consolas, monospace; font-size: .85em; background: #161b22; padding: .1em .3em; border-radius: 3px; }
  .empty { color: #56d364; font-style: italic; padding: .5rem 0; }
  .hint { color: #8b949e; font-size: .85rem; margin-bottom: .75rem; }
  .notice { margin-bottom: 1.5rem; background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: .5rem .75rem; }
  .notice summary { background: none; border: none; color: #d29922; font-size: .85rem; }
  .notice ul { margin: .5rem 0 0 1.5rem; font-size: .82rem; color: #8b949e; }
  .notice li { margin: .25rem 0; }
""";

String _htmlJs() => """
  // Collapse/expand all button would go here if needed.
  // Currently details elements are all open by default for immediate visibility.
""";

String _statCard(String label, String value, {bool warn = false}) =>
    '<div class="stat-card${warn ? ' warn' : ''}">'
    '<div class="label">$label</div>'
    '<div class="value">$value</div>'
    '</div>';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _rel(String absolutePath, String projectRoot) {
  if (absolutePath.startsWith(projectRoot)) {
    final String rel = absolutePath.substring(projectRoot.length);
    return rel.startsWith('/') ? rel.substring(1) : rel;
  }
  return absolutePath;
}

String _topFolder(String relPath) {
  // e.g. "lib/features/auth/..." → "lib/features"
  //      "lib/core/utils/..."   → "lib/core"
  //      "lib/main.dart"        → "lib"
  final List<String> parts = relPath.split('/');
  if (parts.length >= 3) return '${parts[0]}/${parts[1]}';
  if (parts.length >= 2) return parts[0];
  return relPath;
}

int _lineCount(String path) {
  try {
    return File(path).readAsStringSync().split('\n').length;
  } catch (_) {
    return 0;
  }
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _FileInfo {
  _FileInfo({required this.path, required this.lines});
  final String path;
  final int lines;
}
