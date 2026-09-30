import 'package:Prism/core/utils/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = <(String, String, bool)>[
    ('2.6.8', '2.6.9', true),
    ('2.6.9', '2.6.9', false),
    ('2.6.10', '2.6.9', false),
    ('2.9.0', '2.10.0', true),
    ('2.10.0', '2.9.0', false),
    ('3.0.9', '3.0.10', true),
    ('3.0.10', '3.1.0', true),
    ('3.10.0', '4.0.0', true),
    ('3.0', '3.0.0', false),
    ('3.0', '3.0.1', true),
    ('3.0.9', '', false),
    ('', '3.0.9', true),
    ('3.0.9', '3.0.9-beta', false),
    ('2.6.0-beta', '2.6.1', true),
  ];

  for (final (current, minimum, expected) in cases) {
    test('isVersionOlder("$current", "$minimum") is $expected', () {
      expect(isVersionOlder(current, minimum), expected);
    });
  }
}
