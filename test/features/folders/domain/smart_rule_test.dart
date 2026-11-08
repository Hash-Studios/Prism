import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creator rules retain custom UIDs with hyphens and underscores', () {
    expect(
      smartRulesFromDoc(<Map<String, String>>[
        <String, String>{'kind': 'creator', 'value': 'creator-a_1'},
      ]),
      const <SmartRule>[SmartRule(SmartRuleKind.creator, 'creator-a_1')],
    );
  });

  test('creator rules reject UIDs containing a path separator', () {
    expect(
      smartRulesFromDoc(<Map<String, String>>[
        <String, String>{'kind': 'creator', 'value': 'creator/a'},
      ]),
      isEmpty,
    );
  });
}
