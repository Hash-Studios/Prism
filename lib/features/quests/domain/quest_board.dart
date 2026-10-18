import 'dart:math' as math;

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';

enum QuestScope { daily, weekly }

/// What one quest pays when it is done.
class QuestReward {
  const QuestReward({required this.coins, required this.xp});

  final int coins;
  final int xp;
}

/// One quest tile: what to do, how far along it is and what it pays.
class QuestTileModel {
  const QuestTileModel({
    required this.id,
    required this.info,
    required this.scope,
    required this.progress,
    required this.target,
    required this.done,
    required this.reward,
  });

  factory QuestTileModel.of(QuestItem item, QuestScope scope, EconomyAward award) => QuestTileModel(
    id: item.id,
    info: questInfo(item.id),
    scope: scope,
    progress: item.progress,
    target: item.target,
    done: item.claimed,
    reward: scope == QuestScope.weekly
        ? QuestReward(coins: award.weeklyQuestCoins, xp: award.weeklyQuestXp)
        : QuestReward(coins: award.questCoins, xp: award.questXp),
  );

  final String id;
  final QuestInfo info;
  final QuestScope scope;
  final int progress;
  final int target;
  final bool done;
  final QuestReward reward;

  double get fraction => done ? 1 : (progress / target).clamp(0.0, 1.0);
}

enum ChestStage { locked, ready, opened }

/// The bonus item that doubles the chest: a video for free users, the free spin for Pro.
enum BoosterKind { watchAd, proSpin }

class ChestBooster {
  const ChestBooster({required this.kind, required this.claimed});

  factory ChestBooster.of(QuestItem item) =>
      ChestBooster(kind: item.id == 'pro_spin' ? BoosterKind.proSpin : BoosterKind.watchAd, claimed: item.claimed);

  final BoosterKind kind;
  final bool claimed;
}

/// Today's quest board, read once from [QuestState] so the views never branch on raw flags.
class QuestBoard {
  const QuestBoard({required this.daily, required this.chest, required this.doubled, this.booster, this.weekly});

  factory QuestBoard.of(QuestState quests, EconomyAward award) {
    final QuestItem? bonus = quests.bonus;
    final QuestItem? weekly = quests.weekly;
    return QuestBoard(
      daily: <QuestTileModel>[for (final QuestItem q in quests.items) QuestTileModel.of(q, QuestScope.daily, award)],
      chest: quests.chestOpened
          ? ChestStage.opened
          : quests.chestReady
          ? ChestStage.ready
          : ChestStage.locked,
      doubled: quests.chestDoubled,
      booster: bonus == null ? null : ChestBooster.of(bonus),
      weekly: weekly == null ? null : QuestTileModel.of(weekly, QuestScope.weekly, award),
    );
  }

  final List<QuestTileModel> daily;
  final ChestStage chest;

  /// The opened chest paid double.
  final bool doubled;
  final ChestBooster? booster;
  final QuestTileModel? weekly;

  int get doneCount => daily.where((QuestTileModel q) => q.done).length;
}

/// The next UTC midnight, when the daily quests and the chest reset.
DateTime nextDailyReset(DateTime now) {
  final DateTime utc = now.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day + 1);
}

/// The next Monday 00:00 UTC, when the weekly quest resets. Mirrors the ISO week in [economyWeekKey].
DateTime nextWeeklyReset(DateTime now) {
  final DateTime utc = now.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day + 8 - utc.weekday);
}

/// "4d 2h", "13h 40m" or "40m". Never less than "1m".
String formatCountdown(Duration left) {
  if (left.inDays >= 1) return '${left.inDays}d ${left.inHours % 24}h';
  if (left.inHours >= 1) return '${left.inHours}h ${left.inMinutes % 60}m';
  return '${math.max(1, left.inMinutes)}m';
}
