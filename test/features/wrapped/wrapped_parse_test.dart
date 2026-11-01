import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrapped_fixture.dart';

void main() {
  test('keeps showable cards in server order and drops ai, unknown and zero-value cards', () {
    final WrappedYear year = parseWrappedYear(fixtureWrappedDoc())!;

    expect(year.cards.map((WrappedCard c) => c.kind).toList(), <WrappedCardKind>[
      WrappedCardKind.intro,
      WrappedCardKind.saves,
      WrappedCardKind.colours,
      WrappedCardKind.creator,
      WrappedCardKind.streak,
      WrappedCardKind.summary,
    ]);
    final WrappedCard streak = year.cards.firstWhere((WrappedCard c) => c.kind == WrappedCardKind.streak);
    expect(streak.since, DateTime.utc(2026, 3, 2));
  });

  test('returns null when fewer than four stat cards remain', () {
    final Map<String, dynamic> doc = fixtureWrappedDoc();
    final List<Map<String, dynamic>> cards = (doc['cards'] as List<Map<String, dynamic>>)
        .where((Map<String, dynamic> c) => c['id'] != 'creator' && c['id'] != 'streak')
        .toList();
    doc['cards'] = cards;

    expect(parseWrappedYear(doc), isNull);
  });

  test('returns null for another year or another doc version', () {
    final Map<String, dynamic> wrongYear = fixtureWrappedDoc()..['year'] = 2025;
    final Map<String, dynamic> wrongVersion = fixtureWrappedDoc()..['version'] = 2;

    expect(parseWrappedYear(wrongYear), isNull);
    expect(parseWrappedYear(wrongVersion), isNull);
  });
}
