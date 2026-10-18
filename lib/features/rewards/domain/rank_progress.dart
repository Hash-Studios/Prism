import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';

/// A catalog reward stays pending until the server confirms it in inventory.
class RankRewardProgress {
  const RankRewardProgress({required this.item, required this.rank, required this.earned, required this.owned});

  final ShopItem item;
  final RankDef rank;
  final bool earned;
  final bool owned;

  String get name =>
      '${item.name} ${switch (item.kind) {
        ShopItemKind.theme => 'theme',
        ShopItemKind.appIcon => 'app icon',
        ShopItemKind.frame => 'frame',
        ShopItemKind.nameGlow => 'name glow',
      }}';
}

class RankProgress {
  RankProgress({required this.xp, required Set<String> owned, required this.config})
    : rank = config.rankFor(xp),
      rewards = _rewards(xp, owned, config);

  final int xp;
  final EconomyConfig config;
  final Rank rank;
  final List<RankRewardProgress> rewards;

  RankDef? get nextRank => rank.next;
  RankRewardProgress? get nextReward => rewards.where((RankRewardProgress reward) => !reward.owned).firstOrNull;
  int get remainingXp => nextRank == null ? 0 : (nextRank!.min - xp).clamp(0, nextRank!.min);

  static List<RankRewardProgress> _rewards(int xp, Set<String> owned, EconomyConfig config) {
    final List<RankRewardProgress> result = <RankRewardProgress>[];
    for (final ShopItem item in shopCatalog) {
      final RankDef? milestone = config.xp.ranks.where((RankDef rank) => rank.id == item.rankReward).firstOrNull;
      if (item.rankReward == null || milestone == null) continue;
      result.add(
        RankRewardProgress(item: item, rank: milestone, earned: xp >= milestone.min, owned: owned.contains(item.id)),
      );
    }
    result.sort((RankRewardProgress a, RankRewardProgress b) => a.rank.min.compareTo(b.rank.min));
    return List<RankRewardProgress>.unmodifiable(result);
  }
}

String rankTitle(String id) =>
    id.split('_').map((String word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');

String groupedXp(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '\u00A0');
