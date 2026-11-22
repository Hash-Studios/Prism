import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/coin_packs/coin_packs.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Local QA store stub for coin packs. Only the StoreKit leg is fake: a "purchase" asks the QA relay
/// (tool/coin_packs_qa.cjs) to record a store transaction in its fake RevenueCat customer. The real gateway then runs
/// `verifyCoinPurchase` in the Functions emulator, which reads that fake customer.
class LocalQaCoinPacks {
  LocalQaCoinPacks._();

  static final Uri _purchaseUrl = Uri.parse('https://localhost:19375/rc/purchase');
  static const Map<String, String> _prices = <String, String>{
    'prism_coins_100': r'$0.99',
    'prism_coins_300': r'$2.99',
    'prism_coins_700': r'$6.99',
    'prism_coins_1600': r'$14.99',
  };

  static void install() {
    CoinPacksFlag.debugOverride = true;
    coinPackGatewayFactory = () => RevenueCatCoinPackGateway(getOfferings: _offerings, purchase: _purchase);
  }

  static Future<Offerings?> _offerings() async {
    const PresentedOfferingContext context = PresentedOfferingContext('coins', null, null);
    final List<Package> packages = <Package>[
      for (final CoinPackDef def in EconomyConfig.current.coinPacks)
        if (_prices[def.productId] case final String price)
          Package(
            'coins_${def.coins}',
            PackageType.custom,
            StoreProduct(def.productId, '', '', 0, price, 'USD'),
            context,
          ),
    ];
    return Offerings(<String, Offering>{
      'coins': Offering('coins', '', const <String, Object>{}, packages),
    });
  }

  static Future<String> _purchase(Package package) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.postUrl(_purchaseUrl);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(<String, String>{
        'appUserId': app_state.prismUser.id,
        'productId': package.storeProduct.identifier,
      }));
      final HttpClientResponse response = await request.close();
      final Object? body = jsonDecode(await response.transform(utf8.decoder).join());
      if (response.statusCode == 409) {
        throw PlatformException(code: '${PurchasesErrorCode.purchaseCancelledError.index}');
      }
      if (response.statusCode != 200 || body is! Map || body['transactionId'] is! String) {
        throw PlatformException(code: '${PurchasesErrorCode.storeProblemError.index}');
      }
      return body['transactionId'] as String;
    } finally {
      client.close();
    }
  }
}
