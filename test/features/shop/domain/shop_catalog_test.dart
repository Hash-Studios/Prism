import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/shop/domain/cosmetic_styles.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/l10n/l10n.dart';
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
        expect(
          item.rankReward,
          RegExp('rankReward: "(\\w+)"').firstMatch(rest)?.group(1),
          reason: '${item.id} rankReward',
        );
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

  test('the default app icon is injected outside the paid catalog', () {
    expect(defaultAppIcon.kind, ShopItemKind.appIcon);
    expect(defaultAppIcon.price, 0);
    expect(shopItem(defaultAppIcon.id), isNull);
    expect(shopCatalog, isNot(contains(defaultAppIcon)));
    expect(shopItemsOf(ShopItemKind.appIcon).first, same(defaultAppIcon));
    expect(shopItem('icon_noir'), isNotNull);
    expect(shopItemsOf(ShopItemKind.appIcon), contains(shopItem('icon_noir')));
    for (final ShopItemKind kind in ShopItemKind.values.where((ShopItemKind kind) => kind != ShopItemKind.appIcon)) {
      expect(shopItemsOf(kind), shopCatalog.where((ShopItem item) => item.kind == kind).toList(), reason: '$kind');
    }
  });

  test('default and paid icon names use generated localization for every ARB locale', () async {
    final List<File> arbFiles = Directory(
      'lib/l10n',
    ).listSync().whereType<File>().where((File file) => file.path.endsWith('.arb')).toList();
    expect(arbFiles, isNotEmpty);

    for (final File file in arbFiles) {
      final Map<String, dynamic> arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final String locale = arb['@@locale'] as String;
      final Object? defaultIconTranslation = arb['economyShopDefaultIcon'];
      expect(defaultIconTranslation, isA<String>(), reason: locale);
      expect(defaultIconTranslation, isNotEmpty, reason: locale);
      final List<String> localeParts = locale.replaceAll('-', '_').split('_');
      final AppLocalizations l10n = await loadAppLocalizations(
        Locale.fromSubtags(
          languageCode: localeParts.first,
          countryCode: localeParts.length > 1 ? localeParts[1] : null,
        ),
      );
      expect(shopItemName(defaultAppIcon, l10n), defaultIconTranslation, reason: locale);
      expect(shopItemName(shopItem('icon_noir')!, l10n), l10n.economyShopNoir, reason: locale);
      expect(shopItemName(defaultAppIcon, l10n), isNotEmpty, reason: locale);
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
      expect(check('glow_prism', rank: 'gold'), ShopAvailability.rankLocked);
      expect(check('glow_prism', rank: 'prism'), ShopAvailability.available);
    });

    test('a missing reward rank stays locked even above every configured threshold', () {
      final EconomyConfig custom = EconomyConfig.fromMap(<String, dynamic>{
        'xp': <String, Object?>{
          'ranks': <Object?>[
            <String, Object?>{'id': 'bronze', 'min': 0},
            <String, Object?>{'id': 'legend', 'min': 2000000000},
          ],
        },
      });
      expect(
        shopAvailability(shopItem('frame_gold')!, premium: true, rankId: 'legend', now: now, config: custom),
        ShopAvailability.rankLocked,
      );
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
  });

  test('shopFromPrice is the lowest live price, with overrides, skipping founders items once sold out', () {
    final DateTime now = DateTime.utc(2026, 10, 17);
    expect(shopFromPrice(now, config: EconomyConfig.defaults), 100);
    final EconomyConfig cheapFounders = EconomyConfig.fromMap(<String, dynamic>{
      'shopPrices': <String, int>{'frame_founders': 50},
    });
    expect(shopFromPrice(now, config: cheapFounders), 50);
    expect(shopFromPrice(DateTime.utc(2027), config: cheapFounders), 100);
    final EconomyConfig freeRankRewards = EconomyConfig.fromMap(<String, dynamic>{
      'shopPrices': <String, int>{'frame_gold': 0, 'glow_aurora': 0, 'glow_prism': 0},
    });
    expect(shopFromPrice(now, config: freeRankRewards), 100);
  });
}
