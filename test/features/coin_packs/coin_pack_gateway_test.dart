import 'dart:io';

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/coin_packs/data/coin_pack_gateway.dart';
import 'package:Prism/features/coin_packs/domain/coin_pack.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const PresentedOfferingContext _context = PresentedOfferingContext('coins', null, null);

const List<CoinPackDef> _configPacks = <CoinPackDef>[
  CoinPackDef(productId: 'prism_coins_100', coins: 100),
  CoinPackDef(productId: 'prism_coins_300', coins: 330, bonusPercent: 10),
  CoinPackDef(productId: 'prism_coins_700', coins: 840, bonusPercent: 20),
];

const List<Duration> _noWait = <Duration>[Duration.zero, Duration.zero, Duration.zero];

Package _package(String productId, String priceString) => Package(
  '\$rc_$productId',
  PackageType.custom,
  StoreProduct(productId, 'Coins', 'Prism coins', 1.99, priceString, 'USD'),
  _context,
);

/// Store packages in the `coins` offering. One is not in the server config and must be dropped.
final List<Package> _storePackages = <Package>[
  _package('prism_coins_700', '\$8.99'),
  _package('prism_coins_100', '\$0.99'),
  _package('prism_not_in_config', '\$4.99'),
  _package('prism_coins_300', '\$2.99'),
];

Offerings _offerings(List<Package> packages) =>
    Offerings(<String, Offering>{'coins': Offering('coins', 'Coins', const <String, Object>{}, packages)});

CoinPack _pack({bool withPackage = true}) => CoinPack(
  def: _configPacks[1],
  priceString: '\$2.99',
  package: withPackage ? _package('prism_coins_300', '\$2.99') : null,
);

RevenueCatCoinPackGateway _gateway({
  Future<Offerings?> Function()? getOfferings,
  StorePurchase? purchase,
  required VerifyCall verify,
  Future<int> Function()? refreshBalance,
  String Function()? currentUserId,
  Future<bool> Function(String owner)? purchaseIdentityMatches,
  List<CoinPackDef> Function()? configPacks,
}) => RevenueCatCoinPackGateway(
  getOfferings: getOfferings ?? () async => _offerings(_storePackages),
  purchase: purchase ?? _storeSucceeds,
  verify: verify,
  refreshBalance: refreshBalance ?? () async => 400,
  currentUserId: currentUserId ?? () => 'u',
  purchaseIdentityMatches: purchaseIdentityMatches,
  configPacks: configPacks ?? () => _configPacks,
  retryDelays: _noWait,
);

Future<String> _storeSucceeds(Package package) async => 'txn_1';

Future<String> _neverPurchase(Package package) => fail('the store must not be charged');

Future<Map<String, Object?>> _neverVerify(String transactionId) => fail('verify must not be called');

StorePurchase _storeFails(PurchasesErrorCode code) =>
    (Package package) async => throw PlatformException(code: '${code.index}');

Map<String, Object?> _reply(String status, {int coins = 330, int balance = 380}) => <String, Object?>{
  'status': status,
  'coins': coins,
  'balance': balance,
};

void main() {
  group('loadPacks', () {
    test('keeps configured packs, joins coins and bonus, and sorts by coins', () async {
      final RevenueCatCoinPackGateway gateway = _gateway(verify: _neverVerify);

      final List<CoinPack> packs = await gateway.loadPacks();

      expect(packs.map((CoinPack p) => p.productId).toList(), <String>[
        'prism_coins_100',
        'prism_coins_300',
        'prism_coins_700',
      ]);
      expect(packs.map((CoinPack p) => p.coins).toList(), <int>[100, 330, 840]);
      expect(packs.map((CoinPack p) => p.bonusPercent).toList(), <int>[0, 10, 20]);
      expect(packs.map((CoinPack p) => p.priceString).toList(), <String>['\$0.99', '\$2.99', '\$8.99']);
      expect(packs[1].package?.storeProduct.identifier, 'prism_coins_300');
    });

    test('throws CoinPackLoadException when the coins offering is missing', () async {
      final RevenueCatCoinPackGateway gateway = _gateway(
        getOfferings: () async => const Offerings(<String, Offering>{}),
        verify: _neverVerify,
      );

      await expectLater(gateway.loadPacks(), throwsA(isA<CoinPackLoadException>()));
    });

    test('throws CoinPackLoadException when getOfferings returns null', () async {
      final RevenueCatCoinPackGateway gateway = _gateway(getOfferings: () async => null, verify: _neverVerify);

      await expectLater(gateway.loadPacks(), throwsA(isA<CoinPackLoadException>()));
    });

    test('ignores fractional coin counts and normalizes a fractional bonus to zero like the server', () {
      final List<CoinPackDef> packs = CoinPackDef.listFrom(<Object?>[
        <String, Object?>{'productId': 'fractional_coins', 'coins': 100.5, 'bonusPercent': 10},
        <String, Object?>{'productId': 'fractional_bonus', 'coins': 100, 'bonusPercent': 10.5},
        <String, Object?>{'productId': 'integer_pack', 'coins': 200, 'bonusPercent': 20},
      ], const <CoinPackDef>[]);

      expect(packs.map((CoinPackDef pack) => pack.productId), <String>['fractional_bonus', 'integer_pack']);
      expect(packs.map((CoinPackDef pack) => pack.coins), <int>[100, 200]);
      expect(packs.map((CoinPackDef pack) => pack.bonusPercent), <int>[0, 20]);
    });
  });

  group('buy', () {
    test('a store cancel is CoinPackCancelled and never verifies', () async {
      int verifyCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        purchase: _storeFails(PurchasesErrorCode.purchaseCancelledError),
        verify: (String transactionId) async {
          verifyCalls++;
          return _reply('granted');
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackCancelled>());
      expect(verifyCalls, 0);
    });

    test('a store payment pending is CoinPackPending and never verifies', () async {
      int verifyCalls = 0;
      int balanceCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        purchase: _storeFails(PurchasesErrorCode.paymentPendingError),
        verify: (String transactionId) async {
          verifyCalls++;
          return _reply('granted');
        },
        refreshBalance: () async {
          balanceCalls++;
          return 400;
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackPending>());
      expect(verifyCalls, 0);
      expect(balanceCalls, 1);
    });

    test('a non-plugin store error is returned instead of leaving the purchase in flight', () async {
      final RevenueCatCoinPackGateway gateway = _gateway(
        purchase: (Package package) => Future<String>.error(const SocketException('QA relay unavailable')),
        verify: _neverVerify,
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackPending>());
    });

    test('a blank store transaction is pending and refreshes the balance', () async {
      int balanceCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        purchase: (Package package) async => '',
        verify: _neverVerify,
        refreshBalance: () async {
          balanceCalls++;
          return 400;
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackPending>());
      expect(balanceCalls, 1);
    });

    test('a store problem may follow a charge, so it stays pending and never verifies', () async {
      int verifyCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        purchase: _storeFails(PurchasesErrorCode.storeProblemError),
        verify: (String transactionId) async {
          verifyCalls++;
          return _reply('granted');
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackPending>());
      expect(verifyCalls, 0);
    });

    test('another store error is CoinPackFailed and never verifies', () async {
      int verifyCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        purchase: _storeFails(PurchasesErrorCode.networkError),
        verify: (String transactionId) async {
          verifyCalls++;
          return _reply('granted');
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackFailed>().having((CoinPackFailed r) => r.reason, 'reason', 'store_networkError'));
      expect(verifyCalls, 0);
    });

    test('a granted reply keeps the verified server balance and refreshes local state', () async {
      int verifyCalls = 0;
      int balanceCalls = 0;
      int verifying = 0;
      final List<String> sent = <String>[];
      final RevenueCatCoinPackGateway gateway = _gateway(
        verify: (String transactionId) async {
          verifyCalls++;
          sent.add(transactionId);
          return _reply('granted');
        },
        refreshBalance: () async {
          balanceCalls++;
          return 400;
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(
        _pack(),
        onVerifying: () {
          verifying++;
        },
      );

      expect(
        result,
        isA<CoinPackGranted>()
            .having((CoinPackGranted r) => r.coins, 'coins', 330)
            .having((CoinPackGranted r) => r.balance, 'balance', 380),
      );
      expect(sent, <String>['txn_1']);
      expect(verifyCalls, 1);
      expect(balanceCalls, 1);
      expect(verifying, 1);
    });

    test('a balance refresh failure does not hide a confirmed grant', () async {
      final RevenueCatCoinPackGateway gateway = _gateway(
        verify: (String transactionId) async => _reply('granted', balance: 375),
        refreshBalance: () => Future<int>.error(StateError('offline')),
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(
        result,
        isA<CoinPackGranted>()
            .having((CoinPackGranted granted) => granted.coins, 'coins', 330)
            .having((CoinPackGranted granted) => granted.balance, 'balance', 375),
      );
    });

    test('already_granted is CoinPackGranted', () async {
      final RevenueCatCoinPackGateway gateway = _gateway(
        verify: (String transactionId) async => _reply('already_granted'),
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackGranted>().having((CoinPackGranted r) => r.coins, 'coins', 330));
    });

    test('not_found four times is CoinPackPending, with four verify calls and one balance read', () async {
      int verifyCalls = 0;
      int balanceCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        verify: (String transactionId) async {
          verifyCalls++;
          return _reply('not_found');
        },
        refreshBalance: () async {
          balanceCalls++;
          return 400;
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackPending>());
      expect(verifyCalls, 4);
      expect(balanceCalls, 1);
    });

    test('not_found twice then granted is CoinPackGranted after three verify calls', () async {
      int verifyCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        verify: (String transactionId) async {
          verifyCalls++;
          return verifyCalls <= 2 ? _reply('not_found') : _reply('granted');
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackGranted>());
      expect(verifyCalls, 3);
    });

    test('an unavailable error then granted is CoinPackGranted', () async {
      int verifyCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        verify: (String transactionId) async {
          verifyCalls++;
          if (verifyCalls == 1) throw FirebaseFunctionsException(code: 'unavailable', message: 'x');
          return _reply('granted');
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackGranted>());
      expect(verifyCalls, 2);
    });

    test('resource exhaustion after the store purchase is pending, not a retry prompt', () async {
      int verifyCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        verify: (String transactionId) {
          verifyCalls++;
          return Future<Map<String, Object?>>.error(
            FirebaseFunctionsException(code: 'resource-exhausted', message: 'purchase verification throttle'),
          );
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackPending>());
      expect(verifyCalls, 1);
    });

    test('an unauthenticated error is CoinPackFailed with no retry', () async {
      int verifyCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        verify: (String transactionId) {
          verifyCalls++;
          return Future<Map<String, Object?>>.error(FirebaseFunctionsException(code: 'unauthenticated', message: 'x'));
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackFailed>().having((CoinPackFailed r) => r.reason, 'reason', 'server_unauthenticated'));
      expect(verifyCalls, 1);
    });

    test('a refused reply is CoinPackFailed and skips the balance read', () async {
      int balanceCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        verify: (String transactionId) async => <String, Object?>{'status': 'refused', 'reason': 'sandbox_not_allowed'},
        refreshBalance: () async {
          balanceCalls++;
          return 400;
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(
        result,
        isA<CoinPackFailed>().having((CoinPackFailed r) => r.reason, 'reason', 'refused_sandbox_not_allowed'),
      );
      expect(balanceCalls, 0);
    });

    test('an account change after the store purchase is CoinPackPending and never verifies', () async {
      int verifyCalls = 0;
      int userCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        currentUserId: () {
          userCalls++;
          return userCalls == 1 ? 'u' : 'v';
        },
        verify: (String transactionId) async {
          verifyCalls++;
          return _reply('granted');
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackPending>());
      expect(verifyCalls, 0);
    });

    test('an account change during verification does not return the old account grant', () async {
      String userId = 'u';
      final RevenueCatCoinPackGateway gateway = _gateway(
        currentUserId: () => userId,
        verify: (String transactionId) async {
          userId = 'v';
          return _reply('granted');
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackPending>());
    });

    test('an account change during balance refresh does not return the old account balance', () async {
      String userId = 'u';
      final RevenueCatCoinPackGateway gateway = _gateway(
        currentUserId: () => userId,
        verify: (String transactionId) async => _reply('granted'),
        refreshBalance: () async {
          userId = 'v';
          return 400;
        },
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackPending>());
    });

    test('logged-out account cannot start a store purchase', () async {
      int purchaseCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        currentUserId: () => '',
        purchase: (Package package) async {
          purchaseCalls++;
          return 'txn_1';
        },
        verify: _neverVerify,
      );

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackFailed>());
      expect(purchaseCalls, 0);
    });

    test('account changed since offerings loaded cannot start a store purchase', () async {
      String userId = 'u';
      int purchaseCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        currentUserId: () => userId,
        purchase: (Package package) async {
          purchaseCalls++;
          return 'txn_1';
        },
        verify: _neverVerify,
      );
      final List<CoinPack> packs = await gateway.loadPacks();
      userId = 'v';

      final CoinPackPurchaseResult result = await gateway.buy(packs[1]);

      expect(result, isA<CoinPackFailed>());
      expect(purchaseCalls, 0);
    });

    test('removed pack is not purchased from a stale loaded offering', () async {
      List<CoinPackDef> config = _configPacks;
      int purchaseCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        configPacks: () => config,
        purchase: (Package package) async {
          purchaseCalls++;
          return 'txn_1';
        },
        verify: _neverVerify,
      );
      final List<CoinPack> packs = await gateway.loadPacks();
      config = <CoinPackDef>[config.first];

      final CoinPackPurchaseResult result = await gateway.buy(packs[1]);

      expect(result, isA<CoinPackFailed>().having((CoinPackFailed r) => r.reason, 'reason', 'offer_changed'));
      expect(purchaseCalls, 0);
    });

    test('changed pack amount is not purchased from a stale loaded offering', () async {
      List<CoinPackDef> config = _configPacks;
      int purchaseCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        configPacks: () => config,
        purchase: (Package package) async {
          purchaseCalls++;
          return 'txn_1';
        },
        verify: _neverVerify,
      );
      final List<CoinPack> packs = await gateway.loadPacks();
      config = <CoinPackDef>[...config.take(1), const CoinPackDef(productId: 'prism_coins_300', coins: 500)];

      final CoinPackPurchaseResult result = await gateway.buy(packs[1]);

      expect(result, isA<CoinPackFailed>().having((CoinPackFailed r) => r.reason, 'reason', 'offer_changed'));
      expect(purchaseCalls, 0);
    });

    test('a mismatched RevenueCat identity cannot start a store purchase', () async {
      int purchaseCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        purchaseIdentityMatches: (String owner) async => false,
        purchase: (Package package) async {
          purchaseCalls++;
          return 'txn_1';
        },
        verify: _neverVerify,
      );
      await gateway.loadPacks();

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackFailed>());
      expect(purchaseCalls, 0);
    });

    test('account is rechecked after the RevenueCat identity lookup', () async {
      String userId = 'u';
      int purchaseCalls = 0;
      final RevenueCatCoinPackGateway gateway = _gateway(
        currentUserId: () => userId,
        purchaseIdentityMatches: (String owner) async {
          userId = 'v';
          return true;
        },
        purchase: (Package package) async {
          purchaseCalls++;
          return 'txn_1';
        },
        verify: _neverVerify,
      );
      await gateway.loadPacks();

      final CoinPackPurchaseResult result = await gateway.buy(_pack());

      expect(result, isA<CoinPackFailed>());
      expect(purchaseCalls, 0);
    });

    test('a pack without a package is CoinPackFailed and never reaches the store', () async {
      final RevenueCatCoinPackGateway gateway = _gateway(purchase: _neverPurchase, verify: _neverVerify);

      final CoinPackPurchaseResult result = await gateway.buy(_pack(withPackage: false));

      expect(result, isA<CoinPackFailed>().having((CoinPackFailed r) => r.reason, 'reason', 'no_package'));
    });
  });
}
