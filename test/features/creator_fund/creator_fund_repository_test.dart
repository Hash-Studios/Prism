import 'package:Prism/features/creator_fund/data/creator_fund_repository_impl.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_status.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _raw({
  String state = 'off',
  Object? schemaVersion = 1,
  Object? coins,
  Object? shareBps,
  Object? reason,
  int distinctUsers = 3,
}) => <String, Object?>{
  'schemaVersion': schemaVersion,
  'week': '2026-W46',
  'state': state,
  'coins': ?coins,
  'shareBps': ?shareBps,
  'reason': ?reason,
  'distinctUsers': distinctUsers,
  'minDistinctUsers': 5,
  'minPayout': 1,
};

void main() {
  test('parses off, pending and paid', () {
    expect(parseCreatorFundStatus(_raw()), const CreatorFundOff(week: '2026-W46'));
    expect(parseCreatorFundStatus(_raw(state: 'pending')), const CreatorFundPending(week: '2026-W46'));
    expect(
      parseCreatorFundStatus(_raw(state: 'paid', coins: 120, shareBps: 325)),
      const CreatorFundPaid(week: '2026-W46', coins: 120, shareBps: 325),
    );
  });

  test('parses notQualified for every reason', () {
    for (final reason in CreatorFundReason.values) {
      final parsed = parseCreatorFundStatus(_raw(state: 'notQualified', reason: reason.name));
      expect(
        parsed,
        CreatorFundNotQualified(week: '2026-W46', reason: reason, distinctUsers: 3, minDistinctUsers: 5, minPayout: 1),
      );
    }
  });

  test('keeps shareBps on notQualified smallShare', () {
    final parsed = parseCreatorFundStatus(_raw(state: 'notQualified', reason: 'smallShare', shareBps: 12));
    expect(parsed, isA<CreatorFundNotQualified>().having((s) => s.shareBps, 'shareBps', 12));
  });

  test('rejects unsupported schema version', () {
    expect(() => parseCreatorFundStatus(_raw(schemaVersion: 2)), throwsFormatException);
    expect(() => parseCreatorFundStatus(_raw(schemaVersion: '1')), throwsFormatException);
  });

  test('rejects unknown state', () {
    expect(() => parseCreatorFundStatus(_raw(state: 'closed')), throwsFormatException);
  });

  test('rejects negative or non-int coins', () {
    expect(() => parseCreatorFundStatus(_raw(state: 'paid', coins: -1, shareBps: 1)), throwsFormatException);
    expect(() => parseCreatorFundStatus(_raw(state: 'paid', coins: 1.5, shareBps: 1)), throwsFormatException);
    expect(() => parseCreatorFundStatus(_raw(state: 'paid', shareBps: 1)), throwsFormatException);
  });

  test('rejects share outside 0 to 10000 basis points', () {
    expect(() => parseCreatorFundStatus(_raw(state: 'paid', coins: 1, shareBps: 10001)), throwsFormatException);
    expect(() => parseCreatorFundStatus(_raw(state: 'paid', coins: 1, shareBps: -5)), throwsFormatException);
  });

  test('rejects unknown reason and non-map payloads', () {
    expect(() => parseCreatorFundStatus(_raw(state: 'notQualified', reason: 'bored')), throwsFormatException);
    expect(() => parseCreatorFundStatus('not a map'), throwsFormatException);
  });
}
