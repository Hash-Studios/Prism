import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/coins/spin_wheel.dart';

/// How rare a chest slot is. It comes from the slot's odds, so the glow can never disagree with the odds sheet.
enum ChestTier {
  common,
  rare,
  epic,
  legendary;

  /// [share] is the chance of the slot on one chest, 0 to 1.
  static ChestTier forShare(double share) {
    if (share >= 0.25) return common;
    if (share >= 0.10) return rare;
    if (share >= 0.03) return epic;
    return legendary;
  }
}

/// Same slots and odds as `DEFAULT_ECONOMY.award.dailyChest` on the server.
const List<WheelSegment> defaultChest = <WheelSegment>[
  WheelSegment(CoinsPrize(5), weight: 32),
  WheelSegment(CoinsPrize(10), weight: 26),
  WheelSegment(XpPrize(25), weight: 15),
  WheelSegment(CoinsPrize(20), weight: 13),
  WheelSegment(CosmeticPrize(fallbackCoins: 25), weight: 8),
  WheelSegment(CoinsPrize(40), weight: 4),
  WheelSegment(CoinsPrize(100), weight: 2),
];

/// The tier of slot [index] in [slots]. The chest table has the same shape as the wheel table.
ChestTier chestTierOf(List<WheelSegment> slots, int index) {
  final double total = slots.fold<double>(0, (double sum, WheelSegment s) => sum + s.weight);
  if (total <= 0 || index < 0 || index >= slots.length) return ChestTier.common;
  return ChestTier.forShare(slots[index].weight / total);
}

/// Today's chest. Nothing about it is stored apart from today's quests: it opens once a day, and it is free when the
/// three daily quests are done.
class DailyChestStatus {
  const DailyChestStatus({required this.opened, required this.questsLeft, required this.price});

  /// Null when [quests] is missing or not for [today].
  static DailyChestStatus? fromQuests(QuestState? quests, {required String today, required int price}) {
    if (quests == null || quests.dayKey != today || quests.items.isEmpty) return null;
    return DailyChestStatus(
      opened: quests.chestOpened,
      questsLeft: quests.items.where((QuestItem q) => !q.claimed).length,
      price: price,
    );
  }

  final bool opened;

  /// Daily quests still to do before the chest is free.
  final int questsLeft;

  /// What the chest costs before the quests are done.
  final int price;

  bool get free => questsLeft == 0;

  /// What opening costs now. The client sends it as `maxCost`, so the server never charges more than this.
  int get nextCost => free ? 0 : price;

  @override
  bool operator ==(Object other) =>
      other is DailyChestStatus && other.opened == opened && other.questsLeft == questsLeft && other.price == price;

  @override
  int get hashCode => Object.hash(opened, questsLeft, price);
}

/// What the chest held. Cosmetic fallback coins arrive as [coins] with a null [itemId]. [coins] and [xp] are already
/// doubled when the bonus quest doubled the chest.
class ChestWin {
  const ChestWin({required this.slot, this.coins = 0, this.xp = 0, this.itemId});

  /// Index into the reply's slots.
  final int slot;
  final int coins;
  final int xp;
  final String? itemId;
}

enum ChestRefusal { insufficientBalance, priceChanged, alreadyOpened }

sealed class DailyChestResult {
  const DailyChestResult();
}

final class ChestWon extends DailyChestResult {
  const ChestWon({required this.win, required this.cost, required this.doubled, required this.slots});

  final ChestWin win;

  /// What opening cost, 0 when the quests made it free.
  final int cost;

  /// The bonus quest doubled the coins and the XP.
  final bool doubled;

  /// The table the server rolled. Read the prize and the tier from this, not from the cached config.
  final List<WheelSegment> slots;

  WheelPrize get prize => slots[win.slot].prize;

  ChestTier get tier => chestTierOf(slots, win.slot);
}

final class ChestRefused extends DailyChestResult {
  const ChestRefused(this.refusal, {this.price});

  final ChestRefusal refusal;

  /// The server's price when it differs from the one the client showed.
  final int? price;
}

/// No definite reply. A retry replays the same request id, so one tap never opens two chests.
final class ChestFailed extends DailyChestResult {
  const ChestFailed(this.reason);

  final String reason;
}
