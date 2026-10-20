import 'dart:convert';
import 'dart:io';

import 'package:Prism/features/prism_feed/data/wall_search_terms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, dynamic> fixture =
      jsonDecode(File('test/fixtures/wall_search_terms.json').readAsStringSync()) as Map<String, dynamic>;
  final List<Map<String, dynamic>> cases = (fixture['text'] as List<Object?>).cast<Map<String, dynamic>>();

  for (final Map<String, dynamic> testCase in cases) {
    final String text = testCase['text'] as String;
    final List<String> terms = (testCase['terms'] as List<Object?>).cast<String>();
    test('"$text" gives $terms', () {
      expect(searchTermsOf(text), terms);
    });
  }
}
