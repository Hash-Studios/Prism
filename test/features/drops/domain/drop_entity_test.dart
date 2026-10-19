import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import '../drop_fixtures.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();
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
}
