import 'package:Prism/features/theme_mode/domain/custom_accent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAccentHex', () {
    test('parses a hash-prefixed hex code', () {
      expect(parseAccentHex('#e57697'), const Color(0xFFE57697));
    });

    test('parses a bare hex code and ignores surrounding spaces and case', () {
      expect(parseAccentHex(' 00FF00 '), const Color(0xFF00FF00));
    });

    test('returns null for malformed input', () {
      for (final input in ['', '#', 'E5769', 'E576970', '#GG0000', '#E57697FF', 'fff', '# E57697']) {
        expect(parseAccentHex(input), isNull, reason: input);
      }
    });
  });

  group('accentReadsOn', () {
    test('rejects an accent that matches the surface', () {
      expect(accentReadsOn(Colors.white, Colors.white), isFalse);
      expect(accentReadsOn(const Color(0xFF000000), const Color(0xFF000000)), isFalse);
    });

    test('accepts high contrast', () {
      expect(accentReadsOn(Colors.black, Colors.white), isTrue);
    });

    test('switches at the 3:1 threshold', () {
      expect(accentReadsOn(const Color(0xFF949494), Colors.white), isTrue);
      expect(accentReadsOn(const Color(0xFF959595), Colors.white), isFalse);
    });
  });
}
