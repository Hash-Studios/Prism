import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_quests_repository.dart';

void main() {
  const EconomyAward award = EconomyAward(questCoins: 3, questXp: 40, weeklyQuestCoins: 50, weeklyQuestXp: 200);
  const String today = '2026-10-18';
  const int price = 8;
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  List<QuestItem> dailyItems({required int claimed}) => <QuestItem>[
    questItem('set_wall', QuestEvent.setWallpaper, claimed: claimed > 0, progress: claimed > 0 ? 1 : 0),
    questItem('fav_3', QuestEvent.favourite, target: 3, claimed: claimed > 1, progress: claimed > 1 ? 3 : 1),
    questItem('wotd_view', QuestEvent.viewWotd, claimed: claimed > 2, progress: claimed > 2 ? 1 : 0),
  ];

  QuestBoard boardOf({int claimed = 0, bool chestOpened = false, QuestItem? bonus, bool chestDoubled = false}) =>
      QuestBoard.of(
        questState(
          dayKey: today,
          items: dailyItems(claimed: claimed),
          bonus: bonus,
          chestOpened: chestOpened,
          chestDoubled: chestDoubled,
        ),
        award,
        today: today,
        price: price,
        l10n: l10n,
      )!;

  group('rewards', () {
    test('daily tiles pay the daily award and the weekly tile pays the weekly award', () {
      final QuestBoard board = boardOf();

      expect(board.daily.map((QuestTileModel t) => (t.reward.coins, t.reward.xp)), <(int, int)>[
        (3, 40),
        (3, 40),
        (3, 40),
      ]);
      expect(board.weekly!.reward.coins, 50);
      expect(board.weekly!.reward.xp, 200);
      expect(board.weekly!.scope, QuestScope.weekly);
      expect(board.daily.map((QuestTileModel t) => t.scope).toSet(), <QuestScope>{QuestScope.daily});
    });
  });

  group('chest stage', () {
    test('is paid while a daily quest is unclaimed, and it is never locked', () {
      for (final int claimed in <int>[0, 1, 2]) {
        expect(boardOf(claimed: claimed).stage, ChestStage.paid, reason: '$claimed quests claimed');
      }
    });

    test('a paid chest costs the price and counts the quests left', () {
      final DailyChestStatus chest = boardOf(claimed: 1).chest;

      expect(chest.questsLeft, 2);
      expect(chest.price, price);
      expect(chest.nextCost, price);
    });

    test('is free once every daily quest is claimed', () {
      final QuestBoard board = boardOf(claimed: 3);

      expect(board.stage, ChestStage.free);
      expect(board.chest.nextCost, 0);
    });

    test('is opened after the chest is opened, paid or free', () {
      expect(boardOf(claimed: 3, chestOpened: true).stage, ChestStage.opened);
      expect(boardOf(claimed: 1, chestOpened: true).stage, ChestStage.opened);
    });

    test('reports whether the opened chest was doubled', () {
      expect(boardOf(claimed: 3, chestOpened: true, chestDoubled: true).doubled, isTrue);
      expect(boardOf(claimed: 3, chestOpened: true).doubled, isFalse);
    });

    test('takes the price it is given', () {
      final QuestBoard board = QuestBoard.of(
        questState(dayKey: today, items: dailyItems(claimed: 0)),
        award,
        today: today,
        price: 12,
        l10n: l10n,
      )!;

      expect(board.chest.price, 12);
    });

    test('there is no board for quests of another day or without a daily quest', () {
      expect(
        QuestBoard.of(
          questState(dayKey: '2026-10-17', items: dailyItems(claimed: 3)),
          award,
          today: today,
          price: price,
          l10n: l10n,
        ),
        isNull,
      );
      expect(
        QuestBoard.of(
          questState(dayKey: today, items: <QuestItem>[]),
          award,
          today: today,
          price: price,
          l10n: l10n,
        ),
        isNull,
      );
    });
  });

  group('progress', () {
    test('doneCount counts the claimed daily quests', () {
      expect(boardOf().doneCount, 0);
      expect(boardOf(claimed: 2).doneCount, 2);
      expect(boardOf(claimed: 3).doneCount, 3);
    });

    test('fraction is progress over target while a quest is open', () {
      expect(boardOf().daily[1].fraction, closeTo(0.3333, 0.0001));
    });

    test('fraction is full once a quest is done', () {
      expect(boardOf(claimed: 2).daily[1].fraction, 1);
    });
  });

  group('booster', () {
    test('a watch_ad bonus is a video booster', () {
      final ChestBooster booster = boardOf(bonus: questItem('watch_ad', QuestEvent.watchAd)).booster!;

      expect(booster.kind, BoosterKind.watchAd);
      expect(booster.claimed, isFalse);
    });

    test('a pro_spin bonus is the free spin booster', () {
      final ChestBooster booster = boardOf(bonus: questItem('pro_spin', QuestEvent.proSpin)).booster!;

      expect(booster.kind, BoosterKind.proSpin);
      expect(booster.claimed, isFalse);
    });

    test('a claimed bonus is a claimed booster', () {
      final ChestBooster booster = boardOf(
        bonus: questItem('watch_ad', QuestEvent.watchAd, progress: 1, claimed: true),
      ).booster!;

      expect(booster.claimed, isTrue);
    });

    test('there is no booster and no weekly tile when the state has none', () {
      final QuestBoard board = QuestBoard.of(
        QuestState(
          dayKey: '2026-10-18',
          items: dailyItems(claimed: 0),
          chestOpened: false,
          chestDoubled: false,
          weekKey: '2026-W42',
        ),
        award,
        today: today,
        price: price,
        l10n: l10n,
      )!;

      expect(board.booster, isNull);
      expect(board.weekly, isNull);
    });
  });

  group('nextDailyReset', () {
    test('is the next UTC midnight', () {
      expect(nextDailyReset(DateTime.utc(2026, 10, 18, 10, 20)), DateTime.utc(2026, 10, 19));
    });

    test('rolls over the end of the month', () {
      expect(nextDailyReset(DateTime.utc(2026, 10, 31, 23, 59)), DateTime.utc(2026, 11));
    });
  });

  group('nextWeeklyReset', () {
    test('is the next day when it is a Sunday', () {
      expect(nextWeeklyReset(DateTime.utc(2026, 10, 18, 9)), DateTime.utc(2026, 10, 19));
    });

    test('is a full week away just after Monday starts', () {
      expect(nextWeeklyReset(DateTime.utc(2026, 10, 19, 0, 1)), DateTime.utc(2026, 10, 26));
    });
  });

  group('formatCountdown', () {
    test('shows days and hours from one day up', () {
      expect(formatCountdown(l10n, const Duration(days: 4, hours: 2, minutes: 5)), '4d 2h');
    });

    test('shows hours and minutes under a day', () {
      expect(formatCountdown(l10n, const Duration(hours: 13, minutes: 40)), '13h 40m');
    });

    test('shows minutes under an hour', () {
      expect(formatCountdown(l10n, const Duration(minutes: 40)), '40m');
    });

    test('never shows less than a minute', () {
      expect(formatCountdown(l10n, const Duration(seconds: 20)), '1m');
    });
  });
}
