import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();
  const SpinWheelStatus free = SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 5, price: 10);
  const SpinWheelStatus paid = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 3, price: 10);
  const SpinWheelStatus capped = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 0, price: 10);

  test('the best coin slice of the default wheel is 100', () {
    expect(maxWheelCoins(defaultWheel), 100);
    expect(maxWheelCoins(const <WheelSegment>[WheelSegment(XpPrize(5), weight: 1)]), 0);
  });

  group('spinAction', () {
    test('a free spin needs no coins', () {
      expect(spinAction(status: free, balance: 0), SpinAction.spin);
    });

    test('a paid spin needs the price', () {
      expect(spinAction(status: paid, balance: 10), SpinAction.spin);
      expect(spinAction(status: paid, balance: 9), SpinAction.getCoins);
    });

    test('no spins left wins over a short balance', () {
      expect(spinAction(status: capped, balance: 500), SpinAction.capped);
      expect(spinAction(status: capped, balance: 0), SpinAction.capped);
    });
  });

  group('odds', () {
    test('the default wheel is 100 weights, so the percents are the weights', () {
      final List<WheelOdds> odds = wheelOdds(defaultWheel);
      expect(odds.map((WheelOdds o) => o.percent).toList(), <double>[18, 22, 30, 1, 8, 12, 3, 6]);
      expect(odds.map((WheelOdds o) => oddsLabel(o.percent, l10n)).toList(), <String>[
        '18%',
        '22%',
        '30%',
        '1%',
        '8%',
        '12%',
        '3%',
        '6%',
      ]);
    });

    test('a rare slice keeps a decimal, a zero weight shows 0%', () {
      expect(oddsLabel(0.5, l10n), '0.5%');
      expect(oddsLabel(0, l10n), '0%');
      expect(oddsLabel(33.333, l10n), '33.3%');
    });

    test('a wheel with a zero total has no odds', () {
      final List<WheelOdds> odds = wheelOdds(const <WheelSegment>[WheelSegment(CoinsPrize(5), weight: 0)]);
      expect(odds.single.percent, 0);
    });
  });

  group('spinsLeftCaption', () {
    test('says what is left today', () {
      expect(spinsLeftCaption(l10n, free), l10n.economyFreeSpinReady(5));
      expect(spinsLeftCaption(l10n, paid), l10n.economySpinsLeftToday(3));
      expect(
        spinsLeftCaption(l10n, const SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 1, price: 10)),
        l10n.economySpinsLeftToday(1),
      );
      expect(spinsLeftCaption(l10n, capped), 'No spins left today.');
      expect(
        spinsLeftCaption(l10n, const SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 0, price: 10)),
        l10n.economyFreeSpinReady(0),
      );
    });
  });
}
