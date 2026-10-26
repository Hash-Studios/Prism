import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:Prism/l10n/generated/app_localizations_de.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/generated/app_localizations_es.dart';
import 'package:Prism/l10n/generated/app_localizations_hi.dart';
import 'package:Prism/l10n/generated/app_localizations_id.dart';
import 'package:Prism/l10n/generated/app_localizations_pt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../drop_fixtures.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();
  setUpAll(() => initializeDateFormatting());

  group('packPrice', () {
    test('is the pack price when it is cheaper than the walls left', () {
      expect(dropEntity().packPrice(remaining: 4, isPro: false), 100);
    });

    test('is the walls left at the wall price when that is cheaper', () {
      expect(dropEntity().packPrice(remaining: 2, isPro: false), 60);
    });

    test('Pro pays half, rounded up', () {
      expect(dropEntity().packPrice(remaining: 4, isPro: true), 50);
      expect(dropEntity(priceWall: 15).packPrice(remaining: 1, isPro: true), 8);
      expect(dropEntity().wallPrice(isPro: true), 15);
    });

    test('is zero when nothing is left', () {
      expect(dropEntity().packPrice(remaining: 0, isPro: false), 0);
    });
  });

  group('isLiveAt', () {
    test('is true inside the window and false outside', () {
      final drop = dropEntity();
      expect(drop.isLiveAt(DateTime.now()), isTrue);
      expect(drop.isLiveAt(drop.endsAt), isFalse);
      expect(drop.isLiveAt(drop.startsAt.subtract(const Duration(seconds: 1))), isFalse);
    });
  });

  group('endsInLabel', () {
    final drop = dropEntity();

    test('shows days and hours', () {
      expect(
        drop.endsInLabel(l10n, drop.endsAt.subtract(const Duration(days: 3, hours: 4, minutes: 30))),
        'Ends in 3d 4h',
      );
    });

    test('shows hours and minutes in the last day', () {
      expect(drop.endsInLabel(l10n, drop.endsAt.subtract(const Duration(hours: 5, minutes: 20))), 'Ends in 5h 20m');
    });

    test('shows minutes in the last hour and Ended after', () {
      expect(drop.endsInLabel(l10n, drop.endsAt.subtract(const Duration(minutes: 9))), 'Ends in 9m');
      expect(drop.endsInLabel(l10n, drop.endsAt), 'Ended');
    });
  });

  group('phaseAt', () {
    final drop = dropEntity();

    test('is live until the last day, then last call, then ended', () {
      expect(drop.phaseAt(drop.endsAt.subtract(const Duration(hours: 25))), DropPhase.live);
      expect(drop.phaseAt(drop.endsAt.subtract(const Duration(hours: 24))), DropPhase.lastCall);
      expect(drop.phaseAt(drop.endsAt.subtract(const Duration(minutes: 1))), DropPhase.lastCall);
      expect(drop.phaseAt(drop.endsAt), DropPhase.ended);
      expect(drop.phaseAt(drop.startsAt.subtract(const Duration(minutes: 1))), DropPhase.ended);
    });
  });

  group('displayTitle and datesLabel', () {
    DropEntity named(String title) => DropEntity(
      weekKey: '2026-W44',
      title: title,
      startsAt: DateTime.utc(2026, 10, 26),
      endsAt: DateTime.utc(2026, 11, 2),
      priceWall: 30,
      pricePack: 100,
      count: 4,
      walls: const <DropWall>[],
    );

    test('displayTitle returns a real name as it is', () {
      expect(named('Night Swim').displayTitle(l10n), 'Night Swim');
    });

    test('displayTitle reads a week code title as the week of its start', () {
      expect(named('Drop 2026-W44').displayTitle(l10n), 'Week of Oct 26');
    });

    test('displayTitle reads an empty title as the week of its start', () {
      expect(named('').displayTitle(l10n), 'Week of Oct 26');
    });

    test('datesLabel runs from the start to the last day before the end', () {
      expect(named('Night Swim').datesLabel(l10n), 'Oct 26 to Nov 1');
    });

    test('week titles and date labels use UTC dates and each supported locale', () {
      final List<(AppLocalizations, String, String)> locales = <(AppLocalizations, String, String)>[
        (AppLocalizationsEn(), 'Oct 26', 'Nov 1'),
        (AppLocalizationsDe(), '26. Okt.', '1. Nov.'),
        (AppLocalizationsEs(), '26 oct', '1 nov'),
        (AppLocalizationsHi(), '26 अक्टू॰', '1 नव॰'),
        (AppLocalizationsId(), '26 Okt', '1 Nov'),
        (AppLocalizationsPt(), '26 de out.', '1 de nov.'),
        (AppLocalizationsPtBr(), '26 de out.', '1 de nov.'),
      ];
      final DropEntity localTimeZone = DropEntity(
        weekKey: '2026-W44',
        title: 'Drop 2026-W44',
        startsAt: DateTime.fromMillisecondsSinceEpoch(DateTime.utc(2026, 10, 26).millisecondsSinceEpoch),
        endsAt: DateTime.fromMillisecondsSinceEpoch(DateTime.utc(2026, 11, 2).millisecondsSinceEpoch),
        priceWall: 30,
        pricePack: 100,
        count: 4,
        walls: const <DropWall>[],
      );

      for (final (AppLocalizations locale, String start, String end) in locales) {
        expect(localTimeZone.displayTitle(locale), locale.economyDropWeekOf(start), reason: locale.localeName);
        expect(localTimeZone.datesLabel(locale), locale.economyDropDates(start, end), reason: locale.localeName);
      }
    });
  });
}
