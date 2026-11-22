import 'package:Prism/core/coins/economy_config.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _ids(List<CoinPackDef> packs) => packs.map((CoinPackDef p) => p.productId).toList();

List<int> _coins(List<CoinPackDef> packs) => packs.map((CoinPackDef p) => p.coins).toList();

void main() {
  test('defaults sell four packs', () {
    final List<CoinPackDef> packs = EconomyConfig.defaults.coinPacks;

    expect(_ids(packs), <String>['prism_coins_100', 'prism_coins_300', 'prism_coins_700', 'prism_coins_1600']);
    expect(_coins(packs), <int>[100, 330, 840, 2080]);
    expect(packs.map((CoinPackDef p) => p.bonusPercent).toList(), <int>[0, 10, 20, 30]);
  });

  test('a config without coinPacks keeps the default packs', () {
    final EconomyConfig c = EconomyConfig.fromMap(<String, dynamic>{'version': 2});

    expect(_ids(c.coinPacks), _ids(EconomyConfig.defaults.coinPacks));
  });

  test('a raw coinPacks list drops bad entries and keeps the order', () {
    final EconomyConfig c = EconomyConfig.fromMap(<String, dynamic>{
      'coinPacks': <Map<String, dynamic>>[
        <String, dynamic>{'productId': 'prism_coins_300', 'coins': 330, 'bonusPercent': 10},
        <String, dynamic>{'productId': 'Bad Id', 'coins': 50},
        <String, dynamic>{'productId': 'prism_coins_100', 'coins': 0},
        <String, dynamic>{'productId': 'prism_coins_100', 'coins': 100},
        <String, dynamic>{'productId': 'prism_coins_100', 'coins': 999},
        <String, dynamic>{'productId': 'prism_coins_700', 'coins': 840, 'bonusPercent': 20},
      ],
    });

    expect(_ids(c.coinPacks), <String>['prism_coins_300', 'prism_coins_100', 'prism_coins_700']);
    expect(_coins(c.coinPacks), <int>[330, 100, 840]);
    expect(c.coinPacks.map((CoinPackDef p) => p.bonusPercent).toList(), <int>[10, 0, 20]);
  });

  test('a non-list coinPacks value falls back to the defaults', () {
    for (final Object value in <Object>['prism_coins_100', 42, <String, dynamic>{}]) {
      final EconomyConfig c = EconomyConfig.fromMap(<String, dynamic>{'coinPacks': value});

      expect(_ids(c.coinPacks), _ids(EconomyConfig.defaults.coinPacks), reason: 'value: $value');
    }
  });

  test('an empty coinPacks list gives no packs', () {
    final EconomyConfig c = EconomyConfig.fromMap(<String, dynamic>{'coinPacks': <Object>[]});

    expect(c.coinPacks, isEmpty);
  });
}
