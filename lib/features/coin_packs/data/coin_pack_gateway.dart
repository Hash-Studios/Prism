import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/coin_packs/domain/coin_pack.dart';
import 'package:Prism/features/coin_packs/domain/coin_packs_flag.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Loads and buys coin packs. The sheet depends on this, so tests can swap it.
abstract interface class CoinPackGateway {
  /// Packs in the RevenueCat `coins` offering that the server config also sells, fewest coins first.
  /// Throws [CoinPackLoadException] when the offering is missing.
  Future<List<CoinPack>> loadPacks();

  /// Buys [pack] in the store, then asks the server to grant it. Never grants coins on the client.
  /// [onVerifying] runs once the store has charged and the server check starts.
  Future<CoinPackPurchaseResult> buy(CoinPack pack, {VoidCallback? onVerifying});
}

typedef StorePurchase = Future<String> Function(Package package);
typedef VerifyCall = Future<Map<String, Object?>> Function(String transactionId);

/// RevenueCat for the store, `verifyCoinPurchase` for the grant, then a server balance read.
class RevenueCatCoinPackGateway implements CoinPackGateway {
  RevenueCatCoinPackGateway({
    Future<Offerings?> Function()? getOfferings,
    StorePurchase? purchase,
    VerifyCall? verify,
    Future<int> Function()? refreshBalance,
    String Function()? currentUserId,
    Future<bool> Function(String owner)? purchaseIdentityMatches,
    List<CoinPackDef> Function()? configPacks,
    this.retryDelays = const <Duration>[Duration(milliseconds: 1500), Duration(seconds: 3), Duration(seconds: 6)],
  }) : _getOfferings = getOfferings ?? _offerings,
       _purchase = purchase ?? _storePurchase,
       _verify = verify ?? _verifyOnServer,
       _refreshBalance = refreshBalance ?? CoinsService.instance.refreshBalance,
       _currentUserId = currentUserId ?? _eligibleCurrentUserId,
       _purchaseIdentityMatches = purchaseIdentityMatches ?? (purchase == null ? _nativeIdentityMatches : null),
       _configPacks = configPacks ?? (() => EconomyConfig.current.coinPacks);

  static const String offeringId = 'coins';

  final Future<Offerings?> Function() _getOfferings;
  final StorePurchase _purchase;
  final VerifyCall _verify;
  final Future<int> Function() _refreshBalance;
  final String Function() _currentUserId;
  final Future<bool> Function(String owner)? _purchaseIdentityMatches;
  final List<CoinPackDef> Function() _configPacks;
  String? _loadedOwner;

  /// Waits before each retry of a `not_found` or `unavailable` reply.
  final List<Duration> retryDelays;

  static Future<Offerings?> _offerings() async {
    await PurchasesService.instance.ensureConfigured(app_state.prismUser.id);
    return PurchasesService.instance.getOfferings();
  }

  static String _eligibleCurrentUserId() {
    final User? user = FirebaseAuth.instance.currentUser;
    final String prismId = app_state.prismUser.id.trim();
    return user != null && !user.isAnonymous && app_state.prismUser.loggedIn && user.uid == prismId ? prismId : '';
  }

  static Future<bool> _nativeIdentityMatches(String owner) async {
    if (!CoinPacksFlag.available) return false;
    final String appUserId = (await Purchases.appUserID).trim();
    return CoinPacksFlag.available && appUserId == owner;
  }

  static Future<String> _storePurchase(Package package) async {
    final PurchaseResult result = await Purchases.purchase(PurchaseParams.package(package));
    return result.storeTransaction.transactionIdentifier;
  }

  static Future<Map<String, Object?>> _verifyOnServer(String transactionId) async {
    final HttpsCallableResult<Object?> reply = await appFunctions
        .httpsCallable('verifyCoinPurchase', options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
        .call<Object?>(<String, Object?>{'transactionId': transactionId});
    final Object? data = reply.data;
    return data is Map ? data.map((Object? k, Object? v) => MapEntry(k.toString(), v)) : <String, Object?>{};
  }

  @override
  Future<List<CoinPack>> loadPacks() async {
    final String owner = _currentUserId().trim();
    final Offering? offering = (await _getOfferings())?.getOffering(offeringId);
    if (offering == null) throw const CoinPackLoadException('The coins offering is missing.');
    if (_currentUserId().trim() != owner) throw const CoinPackLoadException('The signed-in account changed.');
    _loadedOwner = owner;
    final Map<String, CoinPackDef> defs = <String, CoinPackDef>{
      for (final CoinPackDef def in _configPacks()) def.productId: def,
    };
    final List<CoinPack> packs = <CoinPack>[
      for (final Package package in offering.availablePackages)
        if (defs[package.storeProduct.identifier] case final CoinPackDef def)
          CoinPack(def: def, priceString: package.storeProduct.priceString, package: package),
    ]..sort((CoinPack a, CoinPack b) => a.coins.compareTo(b.coins));
    return packs;
  }

  @override
  Future<CoinPackPurchaseResult> buy(CoinPack pack, {VoidCallback? onVerifying}) async {
    final Package? package = pack.package;
    if (package == null) return const CoinPackFailed('no_package');
    final String owner = _currentUserId().trim();
    if (owner.isEmpty || (_loadedOwner != null && owner != _loadedOwner)) {
      return const CoinPackFailed('account_changed');
    }
    if (!_matchesCurrentConfig(pack)) return const CoinPackFailed('offer_changed');
    try {
      if (_purchaseIdentityMatches != null) {
        final bool identityMatches = await _purchaseIdentityMatches(owner);
        if (!identityMatches || _currentUserId().trim() != owner) {
          return const CoinPackFailed('purchase_identity_mismatch');
        }
      }
    } catch (error) {
      logger.w('Coin pack purchase identity could not be confirmed.', tag: 'CoinPacks', error: error);
      return const CoinPackFailed('purchase_identity_unavailable');
    }
    if (!_matchesCurrentConfig(pack)) return const CoinPackFailed('offer_changed');
    final String transactionId;
    try {
      transactionId = await _purchase(package);
    } on PlatformException catch (error) {
      final PurchasesErrorCode code = PurchasesErrorHelper.getErrorCode(error);
      if (code == PurchasesErrorCode.purchaseCancelledError) return const CoinPackCancelled();
      if (code == PurchasesErrorCode.paymentPendingError) return _pending(owner);
      logger.w('Coin pack purchase failed in the store.', tag: 'CoinPacks', error: error);
      return CoinPackFailed('store_${code.name}');
    } catch (error) {
      // An unexpected store error has an unknown charge outcome. Do not invite a second purchase.
      logger.w('Coin pack purchase ended with an unknown store outcome.', tag: 'CoinPacks', error: error);
      return _pending(owner);
    }
    if (transactionId.isEmpty) return _pending(owner);
    onVerifying?.call();
    final CoinPackPurchaseResult result = await _confirm(transactionId, owner);
    if (_currentUserId().trim() != owner) return const CoinPackPending();
    if (result is CoinPackPending) return _pending(owner);
    if (result is CoinPackGranted) {
      await _refreshBalanceIfCurrent(owner);
      return _currentUserId().trim() == owner ? result : const CoinPackPending();
    }
    return result;
  }

  bool _matchesCurrentConfig(CoinPack pack) {
    for (final CoinPackDef current in _configPacks()) {
      if (current.productId == pack.productId) {
        return current.coins == pack.coins && current.bonusPercent == pack.bonusPercent;
      }
    }
    return false;
  }

  Future<CoinPackPurchaseResult> _pending(String owner) async {
    await _refreshBalanceIfCurrent(owner);
    return const CoinPackPending();
  }

  Future<void> _refreshBalanceIfCurrent(String owner) async {
    if (_currentUserId().trim() != owner) return;
    try {
      await _refreshBalance();
    } catch (error) {
      logger.w('Balance refresh after a coin pack failed.', tag: 'CoinPacks', error: error);
    }
  }

  Future<CoinPackPurchaseResult> _confirm(String transactionId, String owner) async {
    for (int attempt = 0; attempt <= retryDelays.length; attempt++) {
      if (attempt > 0) await Future<void>.delayed(retryDelays[attempt - 1]);
      // A different account now: the webhook grants the purchase to the account that paid.
      if (_currentUserId() != owner) return const CoinPackPending();
      final Map<String, Object?> reply;
      try {
        reply = await _verify(transactionId);
      } on FirebaseFunctionsException catch (error) {
        if (error.code == 'unavailable' || error.code == 'deadline-exceeded' || error.code == 'internal') continue;
        if (error.code == 'resource-exhausted') return const CoinPackPending();
        logger.w('verifyCoinPurchase refused.', tag: 'CoinPacks', error: error);
        return CoinPackFailed('server_${error.code}');
      } catch (error) {
        logger.w('verifyCoinPurchase failed.', tag: 'CoinPacks', error: error);
        continue;
      }
      if (_currentUserId().trim() != owner) return const CoinPackPending();
      switch (reply['status']) {
        case 'granted' || 'already_granted':
          return CoinPackGranted(coins: _int(reply['coins']), balance: _int(reply['balance']));
        case 'not_found':
          continue;
        case 'refused':
          return CoinPackFailed('refused_${reply['reason']}');
        case final Object? status:
          return CoinPackFailed('status_$status');
      }
    }
    return const CoinPackPending();
  }

  static int _int(Object? raw) => raw is num && raw.isFinite ? raw.toInt() : 0;
}
