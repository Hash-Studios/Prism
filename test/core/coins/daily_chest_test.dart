import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spin_wheel_test_helpers.dart';

QuestItem _item(String id, {required bool claimed}) =>
    QuestItem(id: id, event: QuestEvent.share, target: 1, progress: claimed ? 1 : 0, claimed: claimed);

QuestState _quests({
  String dayKey = '2026-10-18',
  List<bool> claimed = const <bool>[true, true, true],
  bool chestOpened = false,
}) => QuestState(
  dayKey: dayKey,
  items: <QuestItem>[for (int i = 0; i < claimed.length; i++) _item('q$i', claimed: claimed[i])],
  chestOpened: chestOpened,
  chestDoubled: false,
  weekKey: '2026-W42',
);

WheelSegment _coins(double weight) => WheelSegment(const CoinsPrize(1), weight: weight);

void main() {
  group('ChestTier.forShare', () {
    test('25 % and more is common', () {
      expect(ChestTier.forShare(0.25), ChestTier.common);
      expect(ChestTier.forShare(1), ChestTier.common);
      expect(ChestTier.forShare(0.2499), ChestTier.rare);
    });

    test('10 % up to 25 % is rare', () {
      expect(ChestTier.forShare(0.10), ChestTier.rare);
      expect(ChestTier.forShare(0.0999), ChestTier.epic);
    });

    test('3 % up to 10 % is epic', () {
      expect(ChestTier.forShare(0.03), ChestTier.epic);
      expect(ChestTier.forShare(0.0299), ChestTier.legendary);
    });

    test('under 3 % is legendary', () {
      expect(ChestTier.forShare(0.02), ChestTier.legendary);
      expect(ChestTier.forShare(0), ChestTier.legendary);
    });
  });

  group('chestTierOf', () {
    test('the seven default slots are common, common, rare, rare, epic, epic, legendary', () {
      expect(
        <ChestTier>[for (int i = 0; i < defaultChest.length; i++) chestTierOf(defaultChest, i)],
        <ChestTier>[
          ChestTier.common,
          ChestTier.common,
          ChestTier.rare,
          ChestTier.rare,
          ChestTier.epic,
          ChestTier.epic,
          ChestTier.legendary,
        ],
      );
    });

    test('the default chest keeps the odds the spec lists, in whole percent, with no XP slot', () {
      expect(describeWheel(defaultChest), defaultChestLines);
      expect(defaultChest.fold<double>(0, (double sum, WheelSegment s) => sum + s.weight), 100);
      expect(defaultChest.map((WheelSegment s) => s.prize), isNot(contains(isA<XpPrize>())));
    });

    test('the tier follows the share of the slot, not its position', () {
      final List<WheelSegment> table = <WheelSegment>[_coins(2), _coins(8), _coins(15), _coins(75)];
      expect(
        <ChestTier>[for (int i = 0; i < table.length; i++) chestTierOf(table, i)],
        <ChestTier>[ChestTier.legendary, ChestTier.epic, ChestTier.rare, ChestTier.common],
      );
    });

    test('a slot on a boundary share takes the higher tier', () {
      final List<WheelSegment> table = <WheelSegment>[_coins(3), _coins(10), _coins(25), _coins(62)];
      expect(
        <ChestTier>[for (int i = 0; i < table.length; i++) chestTierOf(table, i)],
        <ChestTier>[ChestTier.epic, ChestTier.rare, ChestTier.common, ChestTier.common],
      );
    });

    test('an index outside the table and a table without weight are common', () {
      expect(chestTierOf(defaultChest, -1), ChestTier.common);
      expect(chestTierOf(defaultChest, 7), ChestTier.common);
      expect(chestTierOf(<WheelSegment>[_coins(0), _coins(0)], 0), ChestTier.common);
      expect(chestTierOf(const <WheelSegment>[], 0), ChestTier.common);
    });
  });

  group('DailyChestStatus.fromQuests', () {
    const String today = '2026-10-18';

    DailyChestStatus? statusOf(QuestState? quests, {int price = 8}) =>
        DailyChestStatus.fromQuests(quests, today: today, price: price);

    test('is null without quests, for another day and without items', () {
      expect(statusOf(null), isNull);
      expect(statusOf(_quests(dayKey: '2026-10-17')), isNull);
      expect(statusOf(_quests(claimed: const <bool>[])), isNull);
    });

    test('is free when all three daily quests are claimed', () {
      final DailyChestStatus status = statusOf(_quests())!;
      expect((status.opened, status.questsLeft, status.price, status.free, status.nextCost), (false, 0, 8, true, 0));
    });

    test('counts the quests left and charges the price until they are done', () {
      final DailyChestStatus one = statusOf(_quests(claimed: const <bool>[true, false, false]))!;
      expect((one.opened, one.questsLeft, one.free, one.nextCost), (false, 2, false, 8));
      final DailyChestStatus none = statusOf(_quests(claimed: const <bool>[false, false, false]), price: 6)!;
      expect((none.questsLeft, none.free, none.nextCost, none.price), (3, false, 6, 6));
    });

    test('reports an opened chest, free or not', () {
      expect(statusOf(_quests(chestOpened: true))!.opened, isTrue);
      final DailyChestStatus paid = statusOf(_quests(claimed: const <bool>[true, false, true], chestOpened: true))!;
      expect((paid.opened, paid.questsLeft), (true, 1));
    });
  });

  group('ChestWon', () {
    test('reads the prize and the tier from the table the server rolled', () {
      const ChestWon cosmetic = ChestWon(
        win: ChestWin(slot: 4, itemId: 'frame_ring'),
        cost: 8,
        doubled: false,
        slots: defaultChest,
      );
      expect(cosmetic.prize, isA<CosmeticPrize>());
      expect(cosmetic.tier, ChestTier.epic);

      final ChestWon rolled = ChestWon(
        win: const ChestWin(slot: 0, coins: 1),
        cost: 0,
        doubled: false,
        slots: <WheelSegment>[_coins(1), _coins(99)],
      );
      expect(rolled.prize, isA<CoinsPrize>());
      expect(rolled.tier, ChestTier.legendary);
    });
  });
}
