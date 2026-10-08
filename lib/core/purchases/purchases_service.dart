import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/subscription_tier.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/env/env.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  PurchasesService._()
    : _addCustomerInfoListener = Purchases.addCustomerInfoUpdateListener,
      _syncSubscriptionOverride = null,
      _syncRetryBackoff = const Duration(seconds: 2);

  @visibleForTesting
  PurchasesService.forTesting({
    required void Function(CustomerInfoUpdateListener listener) addCustomerInfoListener,
    Future<void> Function()? syncSubscription,
    Duration syncRetryBackoff = Duration.zero,
  }) : _addCustomerInfoListener = addCustomerInfoListener,
       _syncSubscriptionOverride = syncSubscription,
       _syncRetryBackoff = syncRetryBackoff;

  static final PurchasesService instance = PurchasesService._();

  final void Function(CustomerInfoUpdateListener listener) _addCustomerInfoListener;
  final Future<void> Function()? _syncSubscriptionOverride;
  final Duration _syncRetryBackoff;
  bool _configured = false;
  bool _customerInfoListenerRegistered = false;
  String _configuredUserId = '';

  /// Skip redundant Firestore subscription updates when state unchanged (co-ordinate with coin sync / reduce usersv2 writes).
  static const Duration _subscriptionPersistThrottle = Duration(minutes: 5);
  bool? _lastPersistedPremium;
  String? _lastPersistedTier;
  DateTime? _lastPersistSubscriptionTime;

  static const Set<String> _legacyGrandfatheredEntitlementKeys = <String>{
    PurchaseConstants.entitlementPremium,
    PurchaseConstants.entitlementPro,
    PurchaseConstants.entitlementCollections,
  };

  static String _resolveApiKey() {
    final String fallbackApiKey = Env.normalize(Env.rcApiKey);
    final String iosKey = Env.normalize(Env.rcIosApiKey);
    final String androidKey = Env.normalize(Env.rcAndroidApiKey);
    if (Platform.isIOS) return iosKey.isNotEmpty ? iosKey : fallbackApiKey;
    if (Platform.isAndroid) return androidKey.isNotEmpty ? androidKey : fallbackApiKey;
    return androidKey.isNotEmpty ? androidKey : fallbackApiKey;
  }

  Future<void> _configure(String userId) async {
    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    }
    final configuration = PurchasesConfiguration(_resolveApiKey());
    if (userId.isNotEmpty) {
      configuration.appUserID = userId;
    }
    await Purchases.configure(configuration);
    _configured = true;
    _configuredUserId = userId;
    registerCustomerInfoListener();
  }

  /// Keeps premium in step with store changes (renewal, expiry, refund, purchase on another device) while the app
  /// is open. Safe to call more than once.
  @visibleForTesting
  void registerCustomerInfoListener() {
    if (_customerInfoListenerRegistered) return;
    _customerInfoListenerRegistered = true;
    _addCustomerInfoListener((CustomerInfo info) {
      unawaited(
        _applyCustomerInfo(info).catchError((Object error, StackTrace stackTrace) {
          logger.w('Unable to apply a customer info update.', error: error, stackTrace: stackTrace);
          return app_state.prismUser.premium;
        }),
      );
    });
  }

  /// Configures RevenueCat early in app startup (before runApp) so the singleton
  /// is ready before any code, including RevenueCat UI internals, accesses it.
  /// No-op if already configured or if API key is empty.
  Future<void> configureEarly() async {
    if (_configured || _resolveApiKey().isEmpty) return;
    try {
      await _configure('');
    } catch (error, stackTrace) {
      logger.w('RevenueCat early configure failed; will retry on first use.', error: error, stackTrace: stackTrace);
    }
  }

  /// Ensures RevenueCat is configured and logged in as the given user.
  Future<void> ensureConfigured(String userId) async {
    final targetUserId = userId.trim();
    if (!_configured) {
      await _configure(targetUserId);
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
    final DateTime now = DateTime.now();
    if (_lastPersistedPremium == isPremium &&
        _lastPersistedTier == tier.name &&
        _lastPersistSubscriptionTime != null &&
        now.difference(_lastPersistSubscriptionTime!) < _subscriptionPersistThrottle) {
      return;
    }
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        await _callSyncSubscription();
        _lastPersistedPremium = isPremium;
        _lastPersistedTier = tier.name;
        _lastPersistSubscriptionTime = now;
        return;
      } catch (error, stackTrace) {
        if (attempt == 0) {
          await Future<void>.delayed(_syncRetryBackoff);
          continue;
        }
        logger.w('Unable to persist subscription state to Firestore.', error: error, stackTrace: stackTrace);
        analytics.track(
          SubscriptionEntitlementRefreshEvent(
            result: SubscriptionEntitlementRefreshResultValue.failure,
            errorCode: 'sync_subscription',
            errorMessage: '$error',
          ),
        );
      }
    }
  }

  Future<void> _callSyncSubscription() {
    final Future<void> Function()? override = _syncSubscriptionOverride;
    if (override != null) return override();
    // The server owns `premium`/`subscriptionTier`; it derives them itself, so this callable takes no payload.
    return appFunctions
        .httpsCallable('syncSubscription', options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
        .call<dynamic>();
  }

  Future<void> _syncAnalyticsSubscriptionState({required bool isPremium, required SubscriptionTier tier}) async {
    await analytics.setUserProperty(name: AnalyticsUserProperty.subscriptionTier.wireName, value: tier.name);
    await analytics.setUserProperty(name: AnalyticsUserProperty.isPremium.wireName, value: isPremium ? '1' : '0');
  }

  Future<void> _logSubscriptionConversion({
    required SubscriptionTier tier,
    required SubscriptionConversionContext context,
  }) async {
    await analytics.track(
      SubscriptionConversionEvent(
        source: context.source,
        productId: context.productId ?? 'unknown_product',
        packageType: context.packageType ?? 'unknown_package',
        subscriptionTier: context.subscriptionTier ?? tier.name,
        price: context.price ?? 0,
        currency: context.currency ?? 'unknown_currency',
      ),
    );

    final num price = context.price ?? 0;
    if (price > 0) {
      unawaited(analytics.track(RevenueRecordedEvent(amountUsd: price.toDouble(), source: 'revenuecat')));
    }
  }

  /// Checks canonical + grandfathered paid entitlements; updates local user state in local persistence.
  /// Returns the new premium value. Only updates when we successfully fetch CustomerInfo.
  Future<bool> checkAndPersistPremium({SubscriptionConversionContext? conversionContext}) async {
    try {
      await ensureConfigured(app_state.prismUser.id);
      final info = await Purchases.getCustomerInfo();
      return await _applyCustomerInfo(info, conversionContext: conversionContext);
    } on PlatformException catch (e) {
      analytics.track(
        SubscriptionEntitlementRefreshEvent(
          result: SubscriptionEntitlementRefreshResultValue.failure,
          errorCode: e.code,
          errorMessage: e.message ?? '',
        ),
      );
      logger.d('checkAndPersistPremium failed: $e');
      return app_state.prismUser.premium;
    } catch (error, stackTrace) {
      analytics.track(
        SubscriptionEntitlementRefreshEvent(
          result: SubscriptionEntitlementRefreshResultValue.failure,
          errorCode: 'unknown',
          errorMessage: '$error',
        ),
      );
      logger.w('checkAndPersistPremium failed.', error: error, stackTrace: stackTrace);
      return app_state.prismUser.premium;
    }
  }

  Future<bool> _applyCustomerInfo(CustomerInfo info, {SubscriptionConversionContext? conversionContext}) async {
    final bool wasPremium = app_state.prismUser.premium;
    final SubscriptionTier tier = tierFromCustomerInfo(info);
    final bool isPremium = tier.isPaid;

    app_state.prismUser.premium = isPremium;
    app_state.prismUser.subscriptionTier = tier.name;
    app_state.persistPrismUser();
    await _persistSubscriptionStateToFirestore(isPremium: isPremium, tier: tier);
    await _syncAnalyticsSubscriptionState(isPremium: isPremium, tier: tier);
    if (!wasPremium && isPremium && conversionContext != null) {
      await _logSubscriptionConversion(tier: tier, context: conversionContext);
    }
    analytics.track(
      SubscriptionEntitlementRefreshEvent(
        result: SubscriptionEntitlementRefreshResultValue.success,
        subscriptionTier: tier.name,
        isPremium: isPremium ? 1 : 0,
        activeEntitlements: info.entitlements.active.keys.join(','),
      ),
    );
    if (kDebugMode) {
      logger.d('Premium status: $isPremium');
    }
    return isPremium;
  }

  /// Restores store purchases and applies them to this account. Returns whether premium is now active.
  Future<bool> restore() async {
    try {
      await ensureConfigured(app_state.prismUser.id);
      await Purchases.restorePurchases();
    } catch (error, stackTrace) {
      // The caller tells the user; "no purchases found" would be wrong when the store call itself failed.
      logger.w('restorePurchases failed.', error: error, stackTrace: stackTrace);
      rethrow;
    }
    return checkAndPersistPremium();
  }

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
}
