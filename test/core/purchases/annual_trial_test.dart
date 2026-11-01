import 'package:Prism/core/purchases/annual_trial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const String _productId = 'prism_pro_yearly';

const PresentedOfferingContext _context = PresentedOfferingContext('default', null, null);

const Price _freePrice = Price('₹0.00', 0, 'INR');

StoreProduct _iosProduct({required IntroductoryPrice? intro}) {
  return StoreProduct(_productId, 'Prism Pro yearly', 'Prism Pro', 1499, '₹1,499.00', 'INR', introductoryPrice: intro);
}

StoreProduct _androidProduct({required SubscriptionOption? defaultOption}) {
  return StoreProduct(
    _productId,
    'Prism Pro yearly',
    'Prism Pro',
    1499,
    '₹1,499.00',
    'INR',
    defaultOption: defaultOption,
  );
}

Package _annual(StoreProduct product) {
  return Package('\$rc_annual', PackageType.annual, product, _context);
}

Offering _offering(Package? annual) {
  return Offering('default', 'Default', const <String, Object>{}, <Package>[?annual], annual: annual);
}

IntroductoryPrice _iosIntro({required double price, required PeriodUnit unit, required int n, required String period}) {
  return IntroductoryPrice(price, '₹0.00', period, 1, unit, n);
}

SubscriptionOption _androidOption({PricingPhase? freePhase}) {
  return SubscriptionOption(
    'base-yearly',
    _productId,
    _productId,
    const <PricingPhase>[],
    const <String>[],
    true,
    null,
    false,
    null,
    freePhase,
    null,
    null,
    null,
  );
}

PricingPhase _freePhase(Period period) {
  return PricingPhase(period, RecurrenceMode.nonRecurring, 1, _freePrice, null);
}

CustomerInfo _customer({Map<String, EntitlementInfo> active = const <String, EntitlementInfo>{}}) {
  return CustomerInfo(
    EntitlementInfos(active, active),
    const <String, String?>{},
    const <String>[],
    const <String>[],
    const <StoreTransaction>[],
    '',
    'u1',
    const <String, String?>{},
    '',
  );
}

void main() {
  group('trialOfferFor on iOS', () {
    test('offers the annual trial when the intro price is free and the user is eligible', () {
      final Package annual = _annual(
        _iosProduct(
          intro: _iosIntro(price: 0, unit: PeriodUnit.day, n: 7, period: 'P7D'),
        ),
      );

      final lookup = trialOfferFor(
        _offering(annual),
        isIos: true,
        iosEligibility: IntroEligibilityStatus.introEligibilityStatusEligible,
      );

      expect(lookup.offer, isNotNull);
      expect(lookup.offer!.days, 7);
      expect(lookup.offer!.priceString, '₹1,499.00');
      expect(lookup.offer!.productId, 'prism_pro_yearly');
      expect(lookup.reason, isNull);
    });

    test('hides the trial when the user is not eligible', () {
      final Package annual = _annual(
        _iosProduct(
          intro: _iosIntro(price: 0, unit: PeriodUnit.day, n: 7, period: 'P7D'),
        ),
      );

      final lookup = trialOfferFor(
        _offering(annual),
        isIos: true,
        iosEligibility: IntroEligibilityStatus.introEligibilityStatusIneligible,
      );

      expect(lookup.offer, isNull);
      expect(lookup.reason, TrialUnavailableReason.ineligible);
    });

    test('hides the trial when eligibility is unknown or was not checked', () {
      final Package annual = _annual(
        _iosProduct(
          intro: _iosIntro(price: 0, unit: PeriodUnit.day, n: 7, period: 'P7D'),
        ),
      );

      final unknown = trialOfferFor(
        _offering(annual),
        isIos: true,
        iosEligibility: IntroEligibilityStatus.introEligibilityStatusUnknown,
      );
      final notChecked = trialOfferFor(_offering(annual), isIos: true);

      expect(unknown.offer, isNull);
      expect(unknown.reason, TrialUnavailableReason.eligibilityUnknown);
      expect(notChecked.offer, isNull);
      expect(notChecked.reason, TrialUnavailableReason.eligibilityUnknown);
    });

    test('hides the trial when the intro price is paid', () {
      final Package annual = _annual(
        _iosProduct(
          intro: _iosIntro(price: 0.99, unit: PeriodUnit.day, n: 7, period: 'P7D'),
        ),
      );

      final lookup = trialOfferFor(
        _offering(annual),
        isIos: true,
        iosEligibility: IntroEligibilityStatus.introEligibilityStatusEligible,
      );

      expect(lookup.offer, isNull);
      expect(lookup.reason, TrialUnavailableReason.noTrialOffer);
    });

    test('counts a one week intro period as 7 days', () {
      final Package annual = _annual(
        _iosProduct(
          intro: _iosIntro(price: 0, unit: PeriodUnit.week, n: 1, period: 'P1W'),
        ),
      );

      final lookup = trialOfferFor(
        _offering(annual),
        isIos: true,
        iosEligibility: IntroEligibilityStatus.introEligibilityStatusEligible,
      );

      expect(lookup.offer!.days, 7);
      expect(lookup.reason, isNull);
    });
  });

  group('trialOfferFor on Android', () {
    test('offers the trial from the free phase without an eligibility check', () {
      final Package annual = _annual(
        _androidProduct(defaultOption: _androidOption(freePhase: _freePhase(const Period(PeriodUnit.week, 1, 'P1W')))),
      );

      final lookup = trialOfferFor(_offering(annual), isIos: false);

      expect(lookup.offer!.days, 7);
      expect(lookup.offer!.productId, 'prism_pro_yearly');
      expect(lookup.offer!.priceString, '₹1,499.00');
      expect(lookup.reason, isNull);
    });

    test('hides the trial when the default option has no free phase', () {
      final Package annual = _annual(_androidProduct(defaultOption: _androidOption()));

      final lookup = trialOfferFor(_offering(annual), isIos: false);

      expect(lookup.offer, isNull);
      expect(lookup.reason, TrialUnavailableReason.noTrialOffer);
    });
  });

  test('reports no annual package when the offering has none', () {
    final lookup = trialOfferFor(_offering(null), isIos: true);

    expect(lookup.offer, isNull);
    expect(lookup.reason, TrialUnavailableReason.noAnnualPackage);
  });

  group('activeTrialFrom', () {
    test('reads the trial end, renewal and product from the paid entitlement', () {
      final CustomerInfo info = _customer(
        active: <String, EntitlementInfo>{
          'prism_v3_pro_access': const EntitlementInfo(
            'prism_v3_pro_access',
            true,
            true,
            '2026-11-01T10:00:00Z',
            '2026-11-01T10:00:00Z',
            'prism_pro_yearly',
            false,
            periodType: PeriodType.trial,
            expirationDate: '2026-11-08T10:00:00Z',
          ),
        },
      );

      final ActiveTrial? trial = activeTrialFrom(info, now: DateTime.utc(2026, 11, 8));

      expect(trial, isNotNull);
      expect(trial!.endsAt, DateTime.utc(2026, 11, 8, 10));
      expect(trial.willRenew, isTrue);
      expect(trial.productId, 'prism_pro_yearly');
    });

    test('returns null when the paid entitlement is not in a trial', () {
      final CustomerInfo info = _customer(
        active: <String, EntitlementInfo>{
          'prism_v3_pro_access': const EntitlementInfo(
            'prism_v3_pro_access',
            true,
            true,
            '2026-11-01T10:00:00Z',
            '2026-11-01T10:00:00Z',
            'prism_pro_yearly',
            false,
            periodType: PeriodType.normal,
            expirationDate: '2027-11-01T10:00:00Z',
          ),
        },
      );

      expect(activeTrialFrom(info), isNull);
    });

    test('returns null when the trial has expired even if RevenueCat still lists it as active', () {
      final CustomerInfo info = _customer(
        active: <String, EntitlementInfo>{
          'prism_v3_pro_access': const EntitlementInfo(
            'prism_v3_pro_access',
            true,
            true,
            '2026-11-01T10:00:00Z',
            '2026-11-01T10:00:00Z',
            'prism_pro_yearly',
            false,
            periodType: PeriodType.trial,
            expirationDate: '2026-11-08T10:00:00Z',
          ),
        },
      );

      expect(activeTrialFrom(info, now: DateTime.utc(2026, 11, 8, 10)), isNull);
    });

    test('normalizes an offset expiration date to UTC before presenting a local date', () {
      final CustomerInfo info = _customer(
        active: <String, EntitlementInfo>{
          'prism_v3_pro_access': const EntitlementInfo(
            'prism_v3_pro_access',
            true,
            true,
            '2026-11-01T10:00:00Z',
            '2026-11-01T10:00:00Z',
            'prism_pro_yearly',
            false,
            periodType: PeriodType.trial,
            expirationDate: '2026-11-08T12:00:00+02:00',
          ),
        },
      );

      final ActiveTrial? trial = activeTrialFrom(info, now: DateTime.utc(2026, 11, 8));

      expect(trial!.endsAt, DateTime.utc(2026, 11, 8, 10));
      expect(trial.endsAt.toLocal(), DateTime.utc(2026, 11, 8, 10).toLocal());
    });
  });
}
