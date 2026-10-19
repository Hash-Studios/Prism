import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/purchase_analytics.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/subscription_tier.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/env/env.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Singleton service that owns all RevenueCat SDK interactions.
/// Use [checkAndPersistPremium] to sync premium status; use [prismUser.premium] as the single source of truth.
class PurchasesService {
  PurchasesService._()
    : _addCustomerInfoListener = Purchases.addCustomerInfoUpdateListener,
      _syncSubscriptionOverride = null,
      _syncRetryBackoff = const Duration(seconds: 2),
      _configurePurchases = Purchases.configure,
      _logIn = Purchases.logIn,
      _getCustomerInfo = Purchases.getCustomerInfo,
      _apiKey = _resolveApiKey;

  @visibleForTesting
  PurchasesService.forTesting({
    required void Function(CustomerInfoUpdateListener listener) addCustomerInfoListener,
    Future<Map<String, dynamic>> Function()? syncSubscription,
    Duration syncRetryBackoff = Duration.zero,
    Future<void> Function(PurchasesConfiguration configuration)? configurePurchases,
    Future<void> Function(String userId)? logIn,
    Future<CustomerInfo> Function()? getCustomerInfo,
    String Function()? apiKey,
  }) : _addCustomerInfoListener = addCustomerInfoListener,
       _syncSubscriptionOverride = syncSubscription,
       _syncRetryBackoff = syncRetryBackoff,
       _configurePurchases = configurePurchases ?? Purchases.configure,
       _logIn = logIn ?? Purchases.logIn,
       _getCustomerInfo = getCustomerInfo ?? Purchases.getCustomerInfo,
       _apiKey = apiKey ?? _resolveApiKey;

  static final PurchasesService instance = PurchasesService._();

  final void Function(CustomerInfoUpdateListener listener) _addCustomerInfoListener;
  final Future<Map<String, dynamic>> Function()? _syncSubscriptionOverride;
  final Duration _syncRetryBackoff;
  final Future<void> Function(PurchasesConfiguration configuration) _configurePurchases;
  final Future<dynamic> Function(String userId) _logIn;
  final Future<CustomerInfo> Function() _getCustomerInfo;
  final String Function() _apiKey;
  Future<void> _setupQueue = Future<void>.value();
  bool _configured = false;
  bool _customerInfoListenerRegistered = false;
  bool _identityTransitionInProgress = false;
  String _configuredUserId = '';
  int _identityRevision = 0;

  /// Skip redundant Firestore subscription updates when state unchanged (co-ordinate with coin sync / reduce usersv2 writes).
  static const Duration _subscriptionPersistThrottle = Duration(minutes: 5);
  static const Duration _subscriptionResyncAfter = Duration(hours: 24);
  static const String _lastSyncedKeyPrefix = 'lastSyncedSubscription.';
  bool? _lastPersistedPremium;
  String? _lastPersistedUserId;
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
    final configuration = PurchasesConfiguration(_apiKey());
    if (userId.isNotEmpty) {
      configuration.appUserID = userId;
    }
    await _configurePurchases(configuration);
    _configured = true;
    _configuredUserId = userId;
    _identityRevision++;
    registerCustomerInfoListener();
  }

  Future<T> _serializeSetup<T>(Future<T> Function() action) {
    final Future<T> result = _setupQueue.then((_) => action());
    _setupQueue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// Keeps premium in step with store changes (renewal, expiry, refund, purchase on another device) while the app
  /// is open. Safe to call more than once.
  @visibleForTesting
  void registerCustomerInfoListener() {
    if (_customerInfoListenerRegistered) return;
    _customerInfoListenerRegistered = true;
    _addCustomerInfoListener((CustomerInfo info) {
      final String eventUserId = _configuredUserId;
      final int eventIdentityRevision = _identityRevision;
      if (_identityTransitionInProgress || eventUserId != app_state.prismUser.id.trim()) return;
      unawaited(
        Future<void>(() async {
          if (_identityTransitionInProgress ||
              eventIdentityRevision != _identityRevision ||
              eventUserId != _configuredUserId ||
              eventUserId != app_state.prismUser.id.trim()) {
            return;
          }
          await _applyCustomerInfo(info);
        }).catchError((Object error, StackTrace stackTrace) {
          logger.w('Unable to apply a customer info update.', error: error, stackTrace: stackTrace);
        }),
      );
    });
  }

  /// Configures RevenueCat after the first frame so startup is not blocked.
  /// No-op if already configured or if API key is empty.
  Future<void> configureEarly() async {
    if (_apiKey().isEmpty) return;
    try {
      await PerformanceProbe.measure(
        'startup',
        'revenuecat.configure',
        () => _serializeSetup<void>(() async {
          if (!_configured) await _configure('');
        }),
      );
    } catch (error, stackTrace) {
      logger.w('RevenueCat early configure failed; will retry on first use.', error: error, stackTrace: stackTrace);
    }
  }

  /// Ensures RevenueCat is configured and logged in as the given user.
  Future<void> ensureConfigured(String userId) async {
    final targetUserId = userId.trim();
    await _serializeSetup<void>(() async {
      if (!_configured) {
        await _configure(targetUserId);
      } else if (targetUserId.isNotEmpty && targetUserId != _configuredUserId) {
        _identityTransitionInProgress = true;
        try {
          await _logIn(targetUserId);
          _configuredUserId = targetUserId;
          _identityRevision++;
        } on PlatformException catch (e) {
          logger.w('RevenueCat login sync failed: $e');
        } finally {
          _identityTransitionInProgress = false;
        }
      }
    });
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

  SettingsLocalDataSource? get _settings {
    if (!getIt.isRegistered<SettingsLocalDataSource>()) return null;
    final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
    return settings.isOpen ? settings : null;
  }

  /// The last tier the server accepted, with the time, kept across launches so an unchanged tier is not re-synced.
  bool _syncedRecently(String userId, SubscriptionTier tier, DateTime now) {
    final String saved = _settings?.get<String>('$_lastSyncedKeyPrefix$userId', defaultValue: '') ?? '';
    final List<String> parts = saved.split('|');
    final int? syncedAtMs = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (parts.first != tier.name || syncedAtMs == null) return false;
    final Duration age = now.difference(DateTime.fromMillisecondsSinceEpoch(syncedAtMs));
    return !age.isNegative && age < _subscriptionResyncAfter;
  }

  Future<void> _persistSubscriptionStateToFirestore({
    required bool isPremium,
    required SubscriptionTier tier,
    bool force = false,
  }) async {
    final String userId = app_state.prismUser.id.trim();
    if (userId.isEmpty || !app_state.prismUser.loggedIn) {
      return;
    }
    final DateTime now = DateTime.now();
    if (!force && _syncedRecently(userId, tier, now)) return;
    if (!force &&
        _lastPersistedUserId == userId &&
        _lastPersistedPremium == isPremium &&
        _lastPersistedTier == tier.name &&
        _lastPersistSubscriptionTime != null &&
        now.difference(_lastPersistSubscriptionTime!) < _subscriptionPersistThrottle) {
      return;
    }
    for (int attempt = 0; attempt < 2; attempt++) {
      if (userId != app_state.prismUser.id.trim() || !app_state.prismUser.loggedIn) return;
      try {
        final Map<String, dynamic> confirmed = await _callSyncSubscription();
        final Object? confirmedPremium = confirmed['premium'];
        final Object? confirmedTier = confirmed['subscriptionTier'];
        if (confirmedPremium is! bool || confirmedTier is! String) return;
        _lastPersistedUserId = userId;
        _lastPersistedPremium = confirmedPremium;
        _lastPersistedTier = confirmedTier;
        _lastPersistSubscriptionTime = now;
        try {
          await _settings?.set('$_lastSyncedKeyPrefix$userId', '$confirmedTier|${now.millisecondsSinceEpoch}');
        } catch (error, stackTrace) {
          logger.w('Unable to remember the synced subscription.', error: error, stackTrace: stackTrace);
        }
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

  Future<Map<String, dynamic>> _callSyncSubscription() async {
    final Future<Map<String, dynamic>> Function()? override = _syncSubscriptionOverride;
    if (override != null) return override();
    // The server owns `premium`/`subscriptionTier`; it derives them itself, so this callable takes no payload.
    final HttpsCallableResult<dynamic> result = await appFunctions
        .httpsCallable('syncSubscription', options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
        .call<dynamic>();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> _syncAnalyticsSubscriptionState({required bool isPremium, required SubscriptionTier tier}) async {
    await analytics.setUserProperty(name: AnalyticsUserProperty.subscriptionTier.wireName, value: tier.name);
    await analytics.setUserProperty(name: AnalyticsUserProperty.isPremium.wireName, value: isPremium ? '1' : '0');
  }

  /// Checks canonical + grandfathered paid entitlements; updates local user state in local persistence.
  /// Returns the new premium value. Only updates when we successfully fetch CustomerInfo.
  /// [forceSync] waits for the server sync request even when the tier is unchanged.
  Future<bool> checkAndPersistPremium({bool forceSync = false}) async {
    try {
      final String requestedUserId = app_state.prismUser.id.trim();
      await ensureConfigured(requestedUserId);
      if (_configuredUserId != requestedUserId || app_state.prismUser.id.trim() != requestedUserId) {
        return app_state.prismUser.premium;
      }
      final int requestedIdentityRevision = _identityRevision;
      final info = await _getCustomerInfo();
      if (requestedIdentityRevision != _identityRevision ||
          requestedUserId != _configuredUserId ||
          requestedUserId != app_state.prismUser.id.trim()) {
        return app_state.prismUser.premium;
      }
      return await _applyCustomerInfo(info, forceSync: forceSync);
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

  Future<bool> _applyCustomerInfo(CustomerInfo info, {bool forceSync = false}) async {
    final SubscriptionTier tier = tierFromCustomerInfo(info);
    final bool isPremium = tier.isPaid;

    app_state.prismUser.premium = isPremium;
    app_state.prismUser.subscriptionTier = tier.name;
    app_state.persistPrismUser();
    await _persistSubscriptionStateToFirestore(isPremium: isPremium, tier: tier, force: forceSync);
    await _syncAnalyticsSubscriptionState(isPremium: isPremium, tier: tier);
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
      final CustomerInfo info = await Purchases.restorePurchases();
      for (final event in restoredPurchaseEvents(info.entitlements.active.values.map((e) => e.productIdentifier))) {
        analytics.track(event);
      }
    } catch (error, stackTrace) {
      // The caller tells the user; "no purchases found" would be wrong when the store call itself failed.
      logger.w('restorePurchases failed.', error: error, stackTrace: stackTrace);
      rethrow;
    }
    return checkAndPersistPremium(forceSync: true);
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
