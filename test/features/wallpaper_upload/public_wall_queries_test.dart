import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every query on `walls` must either filter `review == true` (the public gate) or be an owner/admin list.
const Set<String> _ownerOrAdminTags = <String>{
  'review.pendingWalls',
  'admin_review.pending_walls',
  'review_batch.pending_walls',
  'review_batch.pending_count',
};

/// Known gaps found by this scan. Each entry is a real public query without the review filter.
/// Keep the entry and its reason until the query is fixed, then delete the entry.
const Map<String, String> _knownBugs = <String, String>{};

class _Block {
  _Block(this.file, this.line, this.text);

  final String file;
  final int line;
  final String text;
}

/// Returns the index of the `)` that closes the `(` at [open], skipping string literals.
int _matchingParen(String source, int open) {
  int depth = 0;
  String? quote;
  for (int i = open; i < source.length; i++) {
    final String ch = source[i];
    if (quote != null) {
      if (ch == r'\') {
        i++;
      } else if (ch == quote) {
        quote = null;
      }
      continue;
    }
    if (ch == "'" || ch == '"') {
      quote = ch;
    } else if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

int _lineOf(String source, int index) => '\n'.allMatches(source.substring(0, index)).length + 1;

Iterable<_Block> _walsBlocks(Directory lib) sync* {
  for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart') || entity.path.endsWith('.freezed.dart')) continue;
    final String source = entity.readAsStringSync();
    int from = 0;
    while (true) {
      final int start = source.indexOf('FirestoreQuerySpec(', from);
      if (start < 0) break;
      final int open = start + 'FirestoreQuerySpec'.length;
      final int close = _matchingParen(source, open);
      if (close < 0) break;
      final String text = source.substring(start, close + 1);
      from = close + 1;
      if (text.contains('collection: FirebaseCollections.walls')) {
        yield _Block(entity.path, _lineOf(source, start), text);
      }
    }
  }
}

/// The tag literal, or its literal prefix when it is interpolated.
String? _sourceTag(String text) {
  final RegExpMatch? match = RegExp(r"sourceTag:\s*'([^']*)").firstMatch(text);
  if (match != null) {
    final String raw = match.group(1)!;
    final int dollar = raw.indexOf(r'$');
    return dollar < 0 ? raw : raw.substring(0, dollar);
  }
  return null;
}

bool _hasReviewTrueFilter(String text) =>
    RegExp(r"field:\s*'review'").hasMatch(text) && RegExp(r'value:\s*true\b').hasMatch(text);

void main() {
  test('every public walls query filters review == true', () {
    final Directory lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'Run from the package root.');

    final List<_Block> blocks = _walsBlocks(lib).toList();
    final List<_Block> publicBlocks = blocks.where((block) {
      final String? tag = _sourceTag(block.text);
      return tag == null || !_ownerOrAdminTags.contains(tag);
    }).toList();

    expect(
      publicBlocks.length,
      greaterThanOrEqualTo(20),
      reason: 'Scanner found only ${publicBlocks.length} public walls queries; the scan is probably broken.',
    );

    final List<String> offenders = <String>[];
    for (final _Block block in publicBlocks) {
      final String tag = _sourceTag(block.text) ?? '<no sourceTag>';
      if (_knownBugs.containsKey(tag)) {
        // ignore: avoid_print
        print('BUG (skipped): ${block.file}:${block.line} $tag: ${_knownBugs[tag]}');
        continue;
      }
      if (_hasReviewTrueFilter(block.text)) continue;
      offenders.add('${block.file}:${block.line} tag=$tag');
    }

    expect(offenders, isEmpty, reason: 'Public walls queries without review == true:\n${offenders.join('\n')}');
  });
}
