import 'dart:io';

import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Singleton service that owns all RevenueCat SDK interactions.
/// Use [checkAndPersistPremium] to sync premium status; use [prismUser.premium] as the single source of truth.
class PurchasesService {
  PurchasesService._();

  static final PurchasesService instance = PurchasesService._();

  bool _configured = false;
  String _configuredUserId = '';

  static const String _rcAndroidApiKey = String.fromEnvironment('RC_ANDROID_API_KEY', defaultValue: apiKey);
  static const String _rcIosApiKey = String.fromEnvironment('RC_IOS_API_KEY', defaultValue: apiKey);

  static String _resolveApiKey() {
    if (Platform.isIOS) return _rcIosApiKey;
    if (Platform.isAndroid) return _rcAndroidApiKey;
    return _rcAndroidApiKey;
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

  bool _isActive(CustomerInfo info, String key) => info.entitlements.all[key]?.isActive ?? false;

  /// Checks [prism_premium] or [prism_ultra]; updates [globals.prismUser.premium] and Hive.
  /// Returns the new premium value. Only updates when we successfully fetch CustomerInfo.
  Future<bool> checkAndPersistPremium() async {
    await ensureConfigured(globals.prismUser.id);

    try {
      final info = await Purchases.getCustomerInfo();
      final isPremium =
          _isActive(info, PurchaseConstants.entitlementPremium) || _isActive(info, PurchaseConstants.entitlementUltra);

      globals.prismUser.premium = isPremium;
      main.prefs.put(main.userHiveKey, globals.prismUser);
      if (kDebugMode) {
        logger.d('Premium status: $isPremium');
      }
      return isPremium;
    } on PlatformException catch (e) {
      logger.d('checkAndPersistPremium failed: $e');
      return globals.prismUser.premium;
    }
  }

  Future<CustomerInfo> purchase(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  Future<CustomerInfo> restore() async => Purchases.restorePurchases();

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      logger.d('getOfferings failed: $e');
      return null;
    }
  }

  /// Logs out the current RC user. No-op if the SDK has not been configured yet,
  /// since there is no session to end and calling logOut before configure
  /// triggers a native fatalError on iOS.
  Future<void> logOut() async {
    if (!_configured) return;
    await Purchases.logOut();
  }

  /// Returns true if [info] grants premium access (prism_premium or prism_ultra).
  bool isPremiumFromCustomerInfo(CustomerInfo info) =>
      _isActive(info, PurchaseConstants.entitlementPremium) || _isActive(info, PurchaseConstants.entitlementUltra);
}
