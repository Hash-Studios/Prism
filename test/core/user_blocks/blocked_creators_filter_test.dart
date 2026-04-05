import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockedCreatorsFilter', () {
    test('normalizeEmail lowercases and trims', () {
      expect(BlockedCreatorsFilter.normalizeEmail('  A@B.COM '), 'a@b.com');
      expect(BlockedCreatorsFilter.normalizeEmail(null), '');
    });

    test('hidesCreatorEmail respects blocked set', () {
      final Set<String> blocked = <String>{'a@b.com'};
      expect(BlockedCreatorsFilter.hidesCreatorEmail('A@B.COM', blocked), isTrue);
      expect(BlockedCreatorsFilter.hidesCreatorEmail('other@test.com', blocked), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorEmail('', blocked), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorEmail('a@b.com', <String>{}), isFalse);
    });
  });
}
