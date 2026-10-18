import 'package:Prism/core/analytics/events/events.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Maps completed SDK receipts. Catalog prices never imply a collected payment.
List<AnalyticsEvent> verifiedPurchaseEvents({
  required StoreTransaction transaction,
  required Package? selectedPackage,
  required List<String> recordedTransactions,
  required String source,
  required String placement,
  required String subscriptionTier,
}) {
  final String id = transaction.transactionIdentifier.trim();
  if (id.isEmpty || recordedTransactions.contains(id)) return const <AnalyticsEvent>[];
  recordedTransactions.add(id);
  if (recordedTransactions.length > 100) recordedTransactions.removeAt(0);
  return <AnalyticsEvent>[
    PurchaseVerifiedEvent(
      productId: transaction.productIdentifier,
      restored: false,
      transactionId: id,
      source: source,
      placement: placement,
    ),
    if (selectedPackage != null && selectedPackage.storeProduct.identifier == transaction.productIdentifier)
      SubscriptionConversionEvent(
        source: source,
        productId: transaction.productIdentifier,
        packageType: selectedPackage.packageType.name,
        subscriptionTier: subscriptionTier,
        price: selectedPackage.storeProduct.price,
        currency: selectedPackage.storeProduct.currencyCode,
        transactionId: id,
        restored: false,
        priceType: 'catalog',
      ),
  ];
}

List<AnalyticsEvent> restoredPurchaseEvents(Iterable<String> productIds) => <AnalyticsEvent>[
  for (final productId in productIds.toSet()) PurchaseVerifiedEvent(productId: productId, restored: true),
];
