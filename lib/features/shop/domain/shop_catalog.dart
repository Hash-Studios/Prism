import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';

enum ShopItemKind { theme, appIcon, frame, nameGlow }

/// Mirrors `functions/src/shopCatalog.ts`. Keep ids and prices in sync; a test compares them.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.price,
    this.proOnly = false,
    this.minRank,
    this.founders = false,
    this.common = false,
    this.themeId,
  });

  final String id;
  final ShopItemKind kind;
  final String name;
  final int price;

  /// Only Pro members may buy it. Ownership survives a lapse; equipping does not.
  final bool proOnly;
  final String? minRank;

  /// Sold only until `flags.foundersUntil`.
  final bool founders;
  final bool common;

  /// For themes, the `PrismThemeOption.id` it unlocks.
  final String? themeId;

  CosmeticSlot? get slot => switch (kind) {
    ShopItemKind.frame => CosmeticSlot.frame,
    ShopItemKind.nameGlow => CosmeticSlot.nameGlow,
    _ => null,
  };
}

const List<ShopItem> shopCatalog = <ShopItem>[
  ShopItem(id: 'theme_rose', kind: ShopItemKind.theme, name: 'Rose', price: 150, themeId: 'kLRose', common: true),
  ShopItem(
    id: 'theme_cotton_blue',
    kind: ShopItemKind.theme,
    name: 'Cotton Blue',
    price: 150,
    themeId: 'kLCotton Blue',
    common: true,
  ),
  ShopItem(id: 'theme_olive', kind: ShopItemKind.theme, name: 'Olive', price: 150, themeId: 'kDOlive', common: true),
  ShopItem(
    id: 'theme_deep_ocean',
    kind: ShopItemKind.theme,
    name: 'Deep Ocean',
    price: 150,
    themeId: 'kDDeep Ocean',
    common: true,
  ),
  ShopItem(id: 'theme_jungle', kind: ShopItemKind.theme, name: 'Jungle', price: 150, themeId: 'kDJungle', common: true),
  ShopItem(id: 'theme_pepper', kind: ShopItemKind.theme, name: 'Pepper', price: 150, themeId: 'kDPepper', common: true),
  ShopItem(id: 'theme_sky', kind: ShopItemKind.theme, name: 'Sky', price: 150, themeId: 'kDSky', common: true),
  ShopItem(id: 'theme_steel', kind: ShopItemKind.theme, name: 'Steel', price: 150, themeId: 'kDSteel', common: true),
  ShopItem(id: 'icon_noir', kind: ShopItemKind.appIcon, name: 'Noir', price: 200),
  ShopItem(id: 'icon_glass', kind: ShopItemKind.appIcon, name: 'Glass', price: 200),
  ShopItem(id: 'icon_sunset', kind: ShopItemKind.appIcon, name: 'Sunset', price: 200),
  ShopItem(id: 'icon_mono', kind: ShopItemKind.appIcon, name: 'Mono', price: 200),
  ShopItem(id: 'frame_ring', kind: ShopItemKind.frame, name: 'Ring', price: 120, common: true),
  ShopItem(id: 'frame_aurora', kind: ShopItemKind.frame, name: 'Aurora', price: 200),
  ShopItem(id: 'frame_prism', kind: ShopItemKind.frame, name: 'Prism', price: 300, proOnly: true),
  ShopItem(id: 'frame_gold', kind: ShopItemKind.frame, name: 'Gold', price: 250, minRank: 'gold'),
  ShopItem(id: 'frame_founders', kind: ShopItemKind.frame, name: 'Founders', price: 1000, founders: true),
  ShopItem(id: 'glow_ember', kind: ShopItemKind.nameGlow, name: 'Ember', price: 100, common: true),
  ShopItem(id: 'glow_ocean', kind: ShopItemKind.nameGlow, name: 'Ocean', price: 100, common: true),
  ShopItem(id: 'glow_aurora', kind: ShopItemKind.nameGlow, name: 'Aurora', price: 200, minRank: 'silver'),
  ShopItem(id: 'glow_founders', kind: ShopItemKind.nameGlow, name: 'Founders', price: 1000, founders: true),
];

ShopItem? shopItem(String id) {
  for (final ShopItem item in shopCatalog) {
    if (item.id == id) return item;
  }
  return null;
}

/// The catalog price unless the economy config overrides it.
int shopPriceFor(ShopItem item) => EconomyConfig.current.shopPrices[item.id] ?? item.price;

List<ShopItem> shopItemsOf(ShopItemKind kind) =>
    shopCatalog.where((ShopItem item) => item.kind == kind).toList(growable: false);

/// Why an item cannot be bought right now. The server decides; this only labels the UI.
enum ShopAvailability { available, proOnly, rankLocked, soldOut }

ShopAvailability shopAvailability(
  ShopItem item, {
  required bool premium,
  required String rankId,
  required DateTime now,
  EconomyConfig? config,
}) {
  final EconomyConfig economy = config ?? EconomyConfig.current;
  if (item.founders) {
    final DateTime? until = economy.flags.foundersUntilAt;
    if (until == null || !now.toUtc().isBefore(until)) return ShopAvailability.soldOut;
  }
  if (item.proOnly && !premium) return ShopAvailability.proOnly;
  final String? needed = item.minRank;
  if (needed != null) {
    final List<RankDef> ranks = economy.xp.ranks;
    final int neededMin = ranks.where((RankDef r) => r.id == needed).firstOrNull?.min ?? 1 << 30;
    final int ownMin = ranks.where((RankDef r) => r.id == rankId).firstOrNull?.min ?? 0;
    if (ownMin < neededMin) return ShopAvailability.rankLocked;
  }
  return ShopAvailability.available;
}

/// Owned by purchase, or a theme the device already used before the shop existed.
bool shopItemOwned(ShopItem item, {required Set<String> owned, required Set<String> legacyThemes}) =>
    owned.contains(item.id) || (item.themeId != null && legacyThemes.contains(item.themeId));

String shopRankName(String id) => id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1)}';
