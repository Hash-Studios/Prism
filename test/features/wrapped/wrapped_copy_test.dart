import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/features/wrapped/views/wrapped_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'wrapped_fixture.dart';

void main() {
  final WrappedYear year = fixtureWrappedYear();
  final WrappedCard colours = year.cards.firstWhere((c) => c.kind == WrappedCardKind.colours);
  final WrappedCard streak = year.cards.firstWhere((c) => c.kind == WrappedCardKind.streak);

  setUpAll(() => initializeDateFormatting('en'));

  test('colour names read as words mid-sentence, except in German', () {
    expect(
      wrappedCopy(lookupAppLocalizations(const Locale('en')), 'en', year, colours).body,
      'Blue, purple and teal showed up most in your saves.',
    );
    expect(wrappedCopy(lookupAppLocalizations(const Locale('de')), 'de', year, colours).body, contains('Blau'));
  });

  test('a late signal says since when, and the screen reader hears it', () {
    final WrappedCopy copy = wrappedCopy(lookupAppLocalizations(const Locale('en')), 'en', year, streak);
    expect(copy.since, 'Since Mar 2');
    expect(copy.semantics, 'Your longest run. 5 days. You checked in 5 days in a row. Since Mar 2.');
  });
}
