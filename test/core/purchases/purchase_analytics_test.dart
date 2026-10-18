import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/purchase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  const package = Package(
    'annual',
    PackageType.annual,
    StoreProduct('pro_annual', '', '', 499, '₹499', 'INR'),
    PresentedOfferingContext('main', null, null),
  );

  List<AnalyticsEvent> purchase(String id, List<String> recorded, {String productId = 'pro_annual'}) =>
      verifiedPurchaseEvents(
        transaction: StoreTransaction(id, productId, ''),
        selectedPackage: package,
        recordedTransactions: recorded,
        source: 'settings',
        placement: 'upsell',
        subscriptionTier: 'pro',
      );

  test('selected package is catalog context and never actual revenue', () {
    final events = purchase('tx1', <String>[]);
    final receipt = events.whereType<PurchaseVerifiedEvent>().single;
    expect(receipt.productId, 'pro_annual');
    expect(receipt.transactionId, 'tx1');
    expect(receipt.amount, isNull);
    final conversion = events.whereType<SubscriptionConversionEvent>().single;
    expect(conversion.price, 499);
    expect(conversion.currency, 'INR');
    expect(conversion.priceType, 'catalog');
    expect(events.whereType<RevenueRecordedEvent>(), isEmpty);
  });

  test('duplicate and missing receipts cannot count twice; history stays bounded', () {
    final recorded = <String>[];
    expect(purchase('', recorded), isEmpty);
    expect(purchase('tx1', recorded), hasLength(2));
    expect(purchase('tx1', recorded), isEmpty);
    for (int i = 2; i < 110; i++) {
      purchase('tx$i', recorded);
    }
    expect(recorded, hasLength(100));
  });

  test('unmatched product cannot borrow selected package price', () {
    final events = purchase('tx2', <String>[], productId: 'other_product');
    expect(events.whereType<PurchaseVerifiedEvent>(), hasLength(1));
    expect(events.whereType<SubscriptionConversionEvent>(), isEmpty);
  });

  test('restore grants receipt context with no revenue or new conversion', () {
    final events = restoredPurchaseEvents(<String>['pro_annual', 'pro_annual']);
    expect(events, hasLength(1));
    final event = events.single as PurchaseVerifiedEvent;
    expect(event.restored, isTrue);
    expect(event.amount, isNull);
    expect(event.transactionId, isNull);
  });
}
