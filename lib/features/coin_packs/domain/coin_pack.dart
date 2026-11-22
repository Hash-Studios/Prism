import 'package:Prism/core/coins/economy_config.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// A pack the sheet can sell: the server's coin amount joined with the store's package and localized price.
@immutable
class CoinPack {
  const CoinPack({required this.def, required this.priceString, this.package});

  final CoinPackDef def;
  final String priceString;

  /// The RevenueCat package to buy. Null only in tests.
  final Package? package;

  String get productId => def.productId;
  int get coins => def.coins;
  int get bonusPercent => def.bonusPercent;
}

/// How one purchase ended, as the sheet shows it.
sealed class CoinPackPurchaseResult {
  const CoinPackPurchaseResult();

  /// Analytics `outcome` value.
  String get outcome;
}

/// The server granted the coins (now or earlier). [balance] is the server balance after the grant.
final class CoinPackGranted extends CoinPackPurchaseResult {
  const CoinPackGranted({required this.coins, required this.balance});

  final int coins;
  final int balance;

  @override
  String get outcome => 'granted';
}

/// The store has not confirmed the payment, or the server has not seen it yet. The webhook grants it later.
final class CoinPackPending extends CoinPackPurchaseResult {
  const CoinPackPending();

  @override
  String get outcome => 'pending';
}

/// The user closed the store sheet. Nothing was charged.
final class CoinPackCancelled extends CoinPackPurchaseResult {
  const CoinPackCancelled();

  @override
  String get outcome => 'cancelled';
}

/// The store failed, or the server refused the grant. [reason] is for logs and analytics, never shown.
final class CoinPackFailed extends CoinPackPurchaseResult {
  const CoinPackFailed(this.reason);

  final String reason;

  @override
  String get outcome => 'failed';
}

/// The RevenueCat `coins` offering could not load.
class CoinPackLoadException implements Exception {
  const CoinPackLoadException(this.message);

  final String message;

  @override
  String toString() => 'CoinPackLoadException: $message';
}
