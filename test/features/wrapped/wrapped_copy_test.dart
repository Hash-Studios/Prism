import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/features/wrapped/views/wrapped_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'wrapped_fixture.dart';

void main() {
  test('creator card copy uses the public username, not the profile name', () async {
    final AppLocalizations l10n = await loadAppLocalizations(const Locale('en'));
    final WrappedYear year = fixtureWrappedYear();
    final WrappedCopy copy = wrappedCopy(l10n, 'en', year, year.cards[3]);

    expect(copy.display, '@maya');
    expect(copy.body, contains('@maya'));
    expect(copy.body, isNot(contains('Maya')));
  });

  test('late-starting stat copy keeps its localized since date in every supported locale', () async {
    const List<WrappedCardKind> lateKinds = <WrappedCardKind>[
      WrappedCardKind.streak,
      WrappedCardKind.ai,
      WrappedCardKind.folders,
      WrappedCardKind.onScreen,
      WrappedCardKind.challenges,
      WrappedCardKind.tips,
    ];
    final DateTime since = DateTime(2026, 3, 2);
    final WrappedYear year = WrappedYear(
      year: 2026,
      through: DateTime.utc(2026, 12, 31),
      accents: const <PrismPaletteColor>[],
      cards: const <WrappedCard>[],
    );

    for (final Locale locale in AppLocalizations.supportedLocales) {
      final AppLocalizations l10n = await loadAppLocalizations(locale);
      await initializeDateFormatting(l10n.localeName);
      for (final WrappedCardKind kind in lateKinds) {
        final WrappedCard card = WrappedCard(kind: kind, heroUrl: '', value: 1, since: since);
        final WrappedCopy copy = wrappedCopy(l10n, l10n.localeName, year, card);
        final String expectedSince = l10n.wrappedSince(DateFormat.MMMd(l10n.localeName).format(since));

        expect(copy.since, expectedSince, reason: '${locale.languageCode}: ${kind.name}');
        expect(copy.semantics, contains(expectedSince), reason: '${locale.languageCode}: ${kind.name} semantics');
        expect(copy.body, isNot(contains('2026')), reason: '${locale.languageCode}: ${kind.name}');
      }
    }
  });

  test('summary rows retain since dates for late-starting stats', () async {
    final AppLocalizations l10n = await loadAppLocalizations(const Locale('en'));
    await initializeDateFormatting(l10n.localeName);
    final DateTime since = DateTime(2026, 2, 19);
    final WrappedCard ai = WrappedCard(kind: WrappedCardKind.ai, heroUrl: '', value: 4, since: since);
    final WrappedYear year = WrappedYear(
      year: 2026,
      through: DateTime.utc(2026, 12, 31),
      accents: const <PrismPaletteColor>[],
      cards: <WrappedCard>[ai],
    );
    final WrappedCopy copy = wrappedCopy(
      l10n,
      'en',
      year,
      const WrappedCard(kind: WrappedCardKind.summary, heroUrl: '', thumbs: <String>['wall']),
    );

    expect(copy.rows.single.$2, contains(l10n.wrappedSince(DateFormat.MMMd('en').format(since))));
  });

  setUpAll(() => initializeDateFormatting('en'));

  final WrappedYear fixtureYear = fixtureWrappedYear();
  final WrappedCard fixtureColours = fixtureYear.cards.firstWhere((c) => c.kind == WrappedCardKind.colours);
  final WrappedCard fixtureStreak = fixtureYear.cards.firstWhere((c) => c.kind == WrappedCardKind.streak);

  test('colour names read as words mid-sentence, except in German', () {
    expect(
      wrappedCopy(lookupAppLocalizations(const Locale('en')), 'en', fixtureYear, fixtureColours).body,
      'Blue, purple and teal showed up most in your saves.',
    );
    expect(
      wrappedCopy(lookupAppLocalizations(const Locale('de')), 'de', fixtureYear, fixtureColours).body,
      contains('Blau'),
    );
  });

  test('a late signal says since when, and the screen reader hears it', () {
    final WrappedCopy copy = wrappedCopy(lookupAppLocalizations(const Locale('en')), 'en', fixtureYear, fixtureStreak);
    expect(copy.since, 'Since Mar 2');
    expect(copy.semantics, 'Your longest run. 5 days. You checked in 5 days in a row. Since Mar 2.');
  });
}
