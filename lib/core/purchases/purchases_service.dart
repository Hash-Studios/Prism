import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/subscription_tier.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionConversionContext {
  const SubscriptionConversionContext({
    required this.source,
    this.productId,
    this.packageType,
    this.subscriptionTier,
    this.price,
    this.currency,
  });

  final String source;
  final String? productId;
  final String? packageType;
  final String? subscriptionTier;
  final num? price;
  final String? currency;
}

/// Singleton service that owns all RevenueCat SDK interactions.
/// Use [checkAndPersistPremium] to sync premium status; use [prismUser.premium] as the single source of truth.
class PurchasesService {
  PurchasesService._();

  static final PurchasesService instance = PurchasesService._();

  bool _configured = false;
  String _configuredUserId = '';
  static const Set<String> _legacyGrandfatheredEntitlementKeys = <String>{
    PurchaseConstants.entitlementPremium,
    PurchaseConstants.entitlementPro,
    PurchaseConstants.entitlementCollections,
  };

  static String _resolveApiKey() {
    const String fallbackApiKey = Env.rcApiKey;
    if (Platform.isIOS) return Env.rcIosApiKey.isNotEmpty ? Env.rcIosApiKey : fallbackApiKey;
    if (Platform.isAndroid) return Env.rcAndroidApiKey.isNotEmpty ? Env.rcAndroidApiKey : fallbackApiKey;
    return Env.rcAndroidApiKey.isNotEmpty ? Env.rcAndroidApiKey : fallbackApiKey;
  }

  /// Ensures RevenueCat is configured and logged in as the given user.
  Future<void> ensureConfigured(String userId) async {
    final targetUserId = userId.trim();
    if (!_configured) {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      final configuration = PurchasesConfiguration(_resolveApiKey());
      if (targetUserId.isNotEmpty) {
        configuration.appUserID = targetUserId;
      }
      await Purchases.configure(configuration);
      _configured = true;
      _configuredUserId = targetUserId;
      return;
    }
    if (targetUserId.isNotEmpty && targetUserId != _configuredUserId) {
      try {
        await Purchases.logIn(targetUserId);
        _configuredUserId = targetUserId;
      } on PlatformException catch (e) {
        logger.w('RevenueCat login sync failed: $e');
      }
    }
  }

  bool _hasLegacyGrandfatheredAccess(String key, EntitlementInfo entitlement) {
    if (!_legacyGrandfatheredEntitlementKeys.contains(key)) {
      return false;
    }
    if (entitlement.latestPurchaseDate.isEmpty) {
      return false;
    }
    final String? expiration = entitlement.expirationDate;
    return expiration == null || expiration.isEmpty;
  }

  bool _hasPaidAccessForEntitlement(String key, EntitlementInfo entitlement) {
    if (entitlement.isActive) {
      return true;
    }
    return _hasLegacyGrandfatheredAccess(key, entitlement);
  }

  bool _hasPaidAccessForKey(CustomerInfo info, String key) {
    final entitlement = info.entitlements.all[key];
    if (entitlement == null) {
      return false;
    }
    return _hasPaidAccessForEntitlement(key, entitlement);
  }

  SubscriptionTier tierFromCustomerInfo(CustomerInfo info) {
    bool paid = false;
    bool lifetime = false;
    for (final key in PurchaseConstants.paidEntitlementKeys) {
      final entitlement = info.entitlements.all[key];
      if (entitlement == null) {
        continue;
      }
      final bool hasAccess = _hasPaidAccessForEntitlement(key, entitlement);
      if (!hasAccess) {
        continue;
      }
      paid = true;
      final String? expiry = entitlement.expirationDate;
      if (expiry == null || expiry.isEmpty) {
        lifetime = true;
      }
    }
    if (!paid) {
      return SubscriptionTier.free;
    }
    return lifetime ? SubscriptionTier.lifetime : SubscriptionTier.pro;
  }

  Future<void> _persistSubscriptionStateToFirestore({required bool isPremium, required SubscriptionTier tier}) async {
    final String userId = app_state.prismUser.id.trim();
    if (userId.isEmpty || !app_state.prismUser.loggedIn) {
      return;
    }
    try {
      await firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
        'premium': isPremium,
        'subscriptionTier': tier.value,
      }, sourceTag: 'purchases.sync_subscription_state');
    } catch (error, stackTrace) {
      logger.w('Unable to persist subscription state to Firestore.', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _syncAnalyticsSubscriptionState({required bool isPremium, required SubscriptionTier tier}) async {
    await analytics.setUserProperty(name: 'subscription_tier', value: tier.value);
    await analytics.setUserProperty(name: 'is_premium', value: isPremium ? '1' : '0');
  }

  Future<void> _logSubscriptionConversion({
    required SubscriptionTier tier,
    SubscriptionConversionContext? conversionContext,
  }) async {
    final SubscriptionConversionContext context =
        conversionContext ??
        const SubscriptionConversionContext(
          source: 'entitlement_refresh',
          productId: 'unknown_product',
          packageType: 'unknown_package',
          currency: 'unknown_currency',
          price: 0,
        );

    await analytics.logEvent(
      name: 'subscription_conversion',
      parameters: <String, Object>{
        'source': context.source,
        'product_id': context.productId ?? 'unknown_product',
        'package_type': context.packageType ?? 'unknown_package',
        'subscription_tier': context.subscriptionTier ?? tier.value,
        'price': context.price ?? 0,
        'currency': context.currency ?? 'unknown_currency',
      },
    );
  }

  /// Checks canonical + grandfathered paid entitlements; updates local user state and Hive.
  /// Returns the new premium value. Only updates when we successfully fetch CustomerInfo.
  Future<bool> checkAndPersistPremium({SubscriptionConversionContext? conversionContext}) async {
    await ensureConfigured(app_state.prismUser.id);

    try {
      final bool wasPremium = app_state.prismUser.premium;
      final info = await Purchases.getCustomerInfo();
      final SubscriptionTier tier = tierFromCustomerInfo(info);
      final bool isPremium = tier.isPaid;

      app_state.prismUser.premium = isPremium;
      app_state.prismUser.subscriptionTier = tier.value;
      app_state.persistPrismUser();
      await _persistSubscriptionStateToFirestore(isPremium: isPremium, tier: tier);
      await _syncAnalyticsSubscriptionState(isPremium: isPremium, tier: tier);
      if (!wasPremium && isPremium) {
        await _logSubscriptionConversion(tier: tier, conversionContext: conversionContext);
      }
      analytics.logEvent(
        name: 'subscription_entitlement_refresh',
        parameters: <String, Object>{
          'result': 'success',
          'subscription_tier': tier.value,
          'is_premium': isPremium ? 1 : 0,
          'active_entitlements': info.entitlements.active.keys.join(','),
        },
      );
      if (kDebugMode) {
        logger.d('Premium status: $isPremium');
      }
      return isPremium;
    } on PlatformException catch (e) {
      analytics.logEvent(
        name: 'subscription_entitlement_refresh',
        parameters: <String, Object>{'result': 'failure', 'error_code': e.code, 'error_message': e.message ?? ''},
      );
      logger.d('checkAndPersistPremium failed: $e');
      return app_state.prismUser.premium;
    }
  }

  Future<CustomerInfo> purchase(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  Future<CustomerInfo> restore() => Purchases.restorePurchases();

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      logger.d('getOfferings failed: $e');
      return null;
    }
  }

  Future<Offering?> getCurrentOfferingForPlacement(String placementIdentifier) async {
    final String placement = placementIdentifier.trim();
    if (placement.isEmpty) {
      return null;
    }
    try {
      return await Purchases.getCurrentOfferingForPlacement(placement);
    } on PlatformException catch (e) {
      logger.d('getCurrentOfferingForPlacement failed: $e');
      return null;
    }
  }

  /// Logs out the current RC user. No-op if the SDK has not been configured yet,
  /// since there is no session to end and calling logOut before configure
  /// triggers a native fatalError on iOS.
  Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } on PlatformException catch (e) {
      final String details = e.details?.toString().toLowerCase() ?? '';
      final String message = e.message?.toLowerCase() ?? '';
      if (e.code == '22' || details.contains('logout_called_with_anonymous_user') || message.contains('anonymous')) {
        logger.w('Skipping RevenueCat logout for anonymous user.');
        return;
      }
      rethrow;
    }
  }

  /// Returns true if [info] grants premium access (prism_premium or prism_ultra).
  bool isPremiumFromCustomerInfo(CustomerInfo info) => tierFromCustomerInfo(info).isPaid;

  bool hasPaidEntitlement(CustomerInfo info, String key) => _hasPaidAccessForKey(info, key);
}
