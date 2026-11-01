import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Why the annual trial timeline is not shown. The normal paywall then shows with no trial wording.
enum TrialUnavailableReason { noAnnualPackage, noTrialOffer, ineligible, eligibilityUnknown }

/// A free trial the store will give this user on the annual package.
class TrialOffer {
  const TrialOffer({required this.package, required this.days});

  final Package package;
  final int days;

  String get productId => package.storeProduct.identifier;

  /// The store's localized renewal price, such as "₹1,499.00".
  String get priceString => package.storeProduct.priceString;
}

typedef TrialOfferLookup = ({TrialOffer? offer, TrialUnavailableReason? reason});

/// The free trial days of a store product, or null when the first phase is not free or is not counted in days.
int? freeTrialDays(StoreProduct product, {required bool isIos}) {
  if (isIos) {
    final IntroductoryPrice? intro = product.introductoryPrice;
    if (intro == null || intro.price != 0 || intro.cycles != 1) return null;
    return _days(intro.periodUnit, intro.periodNumberOfUnits);
  }
  // Play returns only the offers this user can buy, so a free phase here means the user is eligible.
  final Period? period = product.defaultOption?.freePhase?.billingPeriod;
  return period == null ? null : _days(period.unit, period.value);
}

int? _days(PeriodUnit unit, int value) {
  if (value <= 0) return null;
  return switch (unit) {
    PeriodUnit.day => value,
    PeriodUnit.week => value * 7,
    _ => null,
  };
}

/// iOS needs [iosEligibility] from `checkTrialOrIntroductoryPriceEligibility`. Only `eligible` shows the trial:
/// unknown means RevenueCat could not tell, and showing a trial then could be a false promise.
TrialOfferLookup trialOfferFor(Offering offering, {required bool isIos, IntroEligibilityStatus? iosEligibility}) {
  final Package? annual = offering.annual;
  if (annual == null) return (offer: null, reason: TrialUnavailableReason.noAnnualPackage);
  final int? days = freeTrialDays(annual.storeProduct, isIos: isIos);
  if (days == null) return (offer: null, reason: TrialUnavailableReason.noTrialOffer);
  if (isIos && iosEligibility != IntroEligibilityStatus.introEligibilityStatusEligible) {
    return (
      offer: null,
      reason: iosEligibility == IntroEligibilityStatus.introEligibilityStatusIneligible
          ? TrialUnavailableReason.ineligible
          : TrialUnavailableReason.eligibilityUnknown,
    );
  }
  return (offer: TrialOffer(package: annual, days: days), reason: null);
}

/// A paid entitlement that is in its free trial period.
class ActiveTrial {
  const ActiveTrial({required this.productId, required this.endsAt, required this.willRenew});

  final String productId;

  /// When the trial ends and the store charges, in UTC.
  final DateTime endsAt;

  /// False once the user turns off auto-renew. The trial then ends with no charge.
  final bool willRenew;
}

ActiveTrial? activeTrialFrom(CustomerInfo info, {DateTime? now}) {
  for (final String key in PurchaseConstants.paidEntitlementKeys) {
    final EntitlementInfo? entitlement = info.entitlements.active[key];
    if (entitlement == null || entitlement.periodType != PeriodType.trial) continue;
    final DateTime? endsAt = DateTime.tryParse(entitlement.expirationDate ?? '');
    if (endsAt == null || !endsAt.isAfter(now ?? DateTime.now())) continue;
    return ActiveTrial(
      productId: entitlement.productIdentifier,
      endsAt: endsAt.toUtc(),
      willRenew: entitlement.willRenew,
    );
  }
  return null;
}
