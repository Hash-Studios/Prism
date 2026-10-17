import 'dart:io';

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/shop/domain/cosmetic_styles.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(EconomyConfig.resetForTest);

  group('parity with functions/src/shopCatalog.ts', () {
    final RegExp entry = RegExp(r'\{id: "([^"]+)", kind: "(\w+)", name: "([^"]+)", price: (\d+)([^}]*)\}');
    late List<RegExpMatch> serverItems;

    setUpAll(() {
      serverItems = entry.allMatches(File('functions/src/shopCatalog.ts').readAsStringSync()).toList();
    });

    test('the server list was parsed', () {
      expect(serverItems.length, greaterThanOrEqualTo(21));
    });

    test('every server id exists in the Dart catalog with the same kind, name, price and flags', () {
      for (final RegExpMatch m in serverItems) {
        final ShopItem? item = shopItem(m.group(1)!);
        final String rest = m.group(5)!;
        expect(item, isNotNull, reason: '${m.group(1)} is missing from the Dart catalog');
        expect(item!.kind.name, m.group(2), reason: '${item.id} kind');
        expect(item.name, m.group(3), reason: '${item.id} name');
        expect(item.price, int.parse(m.group(4)!), reason: '${item.id} price');
        expect(item.proOnly, rest.contains('proOnly: true'), reason: '${item.id} proOnly');
        expect(item.founders, rest.contains('founders: true'), reason: '${item.id} founders');
        expect(item.common, rest.contains('common: true'), reason: '${item.id} common');
        expect(item.minRank, RegExp('minRank: "(\\w+)"').firstMatch(rest)?.group(1), reason: '${item.id} minRank');
        expect(item.themeId, RegExp('themeId: "([^"]+)"').firstMatch(rest)?.group(1), reason: '${item.id} themeId');
      }
    });

    test('the Dart catalog has no id the server lacks', () {
      expect(shopCatalog.map((ShopItem i) => i.id).toSet(), serverItems.map((RegExpMatch m) => m.group(1)).toSet());
    });
  });

  test('every locked theme option matches a catalog theme with its own id', () {
    final List<PrismThemeOption> locked = <PrismThemeOption>[
      ...prismLightThemes,
      ...prismDarkThemes,
    ].where((PrismThemeOption o) => o.shopItemId != null).toList();
    expect(locked, hasLength(shopItemsOf(ShopItemKind.theme).length));
    for (final PrismThemeOption option in locked) {
      expect(shopItem(option.shopItemId!)!.themeId, option.id);
    }
  });

  group('shopPriceFor', () {
    test('uses the catalog price', () {
      expect(shopPriceFor(shopItem('frame_ring')!), 120);
    });

    test('a config override wins', () {
      EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
        'shopPrices': <String, dynamic>{'frame_ring': 60},
      });
      expect(shopPriceFor(shopItem('frame_ring')!), 60);
      expect(shopPriceFor(shopItem('frame_aurora')!), 200);
    });
  });

  group('shopAvailability', () {
    final DateTime now = DateTime.utc(2026, 10, 17);

    ShopAvailability check(String id, {bool premium = false, String rank = 'bronze', DateTime? at}) =>
        shopAvailability(shopItem(id)!, premium: premium, rankId: rank, now: at ?? now);

    test('plain items are available', () {
      expect(check('theme_rose'), ShopAvailability.available);
    });

    test('a Pro item needs premium', () {
      expect(check('frame_prism'), ShopAvailability.proOnly);
      expect(check('frame_prism', premium: true), ShopAvailability.available);
    });

    test('a rank item needs that rank or higher', () {
      expect(check('frame_gold', rank: 'silver'), ShopAvailability.rankLocked);
      expect(check('frame_gold', rank: 'gold'), ShopAvailability.available);
      expect(check('frame_gold', rank: 'prism'), ShopAvailability.available);
      expect(check('glow_aurora'), ShopAvailability.rankLocked);
      expect(check('glow_aurora', rank: 'silver'), ShopAvailability.available);
    });

    test('a founders item sells until the config date', () {
      expect(check('frame_founders'), ShopAvailability.available);
      expect(check('frame_founders', at: DateTime.utc(2026, 12)), ShopAvailability.soldOut);
    });
  });

  group('shopItemOwned', () {
    test('a purchase counts', () {
      expect(shopItemOwned(shopItem('frame_ring')!, owned: {'frame_ring'}, legacyThemes: {}), isTrue);
    });

    test('a legacy theme counts, a legacy id of another kind does not', () {
      expect(shopItemOwned(shopItem('theme_rose')!, owned: {}, legacyThemes: {'kLRose'}), isTrue);
      expect(shopItemOwned(shopItem('theme_olive')!, owned: {}, legacyThemes: {'kLRose'}), isFalse);
      expect(shopItemOwned(shopItem('frame_ring')!, owned: {}, legacyThemes: {'kLRose'}), isFalse);
    });
  });

  group('cosmetic styles', () {
    test('every frame and glow in the catalog has a style with two or more colours', () {
      for (final ShopItem item in shopItemsOf(ShopItemKind.frame)) {
        expect(frameStyle(item.id).colors.length, greaterThanOrEqualTo(2), reason: item.id);
        expect(frameStyle(item.id).width, greaterThan(0));
      }
      for (final ShopItem item in shopItemsOf(ShopItemKind.nameGlow)) {
        expect(glowStyle(item.id).colors.length, greaterThanOrEqualTo(2), reason: item.id);
      }
    });

    test('the ring follows the accent and the others do not', () {
      const Color accent = Color(0xff123456);
      expect(frameStyle('frame_ring', accent: accent).colors, everyElement(accent));
      expect(frameStyle('frame_gold', accent: accent).colors, isNot(contains(accent)));
    });

    test('the prism frame carries the Glint ring colours', () {
      expect(frameStyle('frame_prism').colors.length, 9);
    });
  });
}
