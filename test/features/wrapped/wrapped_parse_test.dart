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

  test('returns null when the server sends more than seven stat cards', () {
    final Map<String, dynamic> doc = fixtureWrappedDoc();
    final List<Map<String, dynamic>> cards = (doc['cards'] as List<Map<String, dynamic>>)
        .where((Map<String, dynamic> card) => card['id'] != 'ai' && card['id'] != 'mystery')
        .toList();
    cards.insertAll(5, <Map<String, dynamic>>[
      <String, dynamic>{'id': 'folders', 'value': 1},
      <String, dynamic>{'id': 'onScreen', 'value': 1},
      <String, dynamic>{'id': 'challenges', 'value': 1},
      <String, dynamic>{'id': 'tips', 'value': 1},
    ]);
    doc['cards'] = cards;

    expect(parseWrappedYear(doc), isNull);
  });

  test('returns null when intro or summary cards are duplicated', () {
    final Map<String, dynamic> duplicateIntro = fixtureWrappedDoc();
    final List<Map<String, dynamic>> introCards = List<Map<String, dynamic>>.from(
      duplicateIntro['cards'] as List<Map<String, dynamic>>,
    );
    introCards.insert(1, Map<String, dynamic>.from(introCards.first));
    duplicateIntro['cards'] = introCards;

    final Map<String, dynamic> duplicateSummary = fixtureWrappedDoc();
    final List<Map<String, dynamic>> summaryCards = List<Map<String, dynamic>>.from(
      duplicateSummary['cards'] as List<Map<String, dynamic>>,
    );
    summaryCards.insert(summaryCards.length - 1, Map<String, dynamic>.from(summaryCards.last));
    duplicateSummary['cards'] = summaryCards;

    expect(parseWrappedYear(duplicateIntro), isNull);
    expect(parseWrappedYear(duplicateSummary), isNull);
  });

  test('returns null when a stat card id is duplicated', () {
    final Map<String, dynamic> doc = fixtureWrappedDoc();
    final List<Map<String, dynamic>> cards = List<Map<String, dynamic>>.from(
      doc['cards'] as List<Map<String, dynamic>>,
    );
    cards.insert(2, Map<String, dynamic>.from(cards[1]));
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
