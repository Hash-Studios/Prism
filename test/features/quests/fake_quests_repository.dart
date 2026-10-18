import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/quests/domain/repositories/quests_repository.dart';
import 'package:flutter/foundation.dart';

class FakeQuestsRepository implements QuestsRepository {
  FakeQuestsRepository({QuestState? quests}) {
    this.quests.value = quests;
  }

  final ValueNotifier<QuestState?> quests = ValueNotifier<QuestState?>(null);
  final ValueNotifier<List<QuestAward>> awards = ValueNotifier<List<QuestAward>>(const <QuestAward>[]);
  int refreshes = 0;
  int consumed = 0;

  @override
  Stream<QuestState?> watchQuests() => _watch(quests);

  @override
  Stream<List<QuestAward>> watchAwards() => _watch(awards);

  @override
  Future<void> refresh() async => refreshes++;

  @override
  void consumeAwards() {
    consumed++;
    awards.value = const <QuestAward>[];
  }

  Stream<T> _watch<T>(ValueNotifier<T> source) async* {
    yield source.value;
    final StreamController<T> controller = StreamController<T>();
    void push() => controller.add(source.value);
    source.addListener(push);
    try {
      yield* controller.stream;
    } finally {
      source.removeListener(push);
      await controller.close();
    }
  }
}

QuestItem questItem(String id, QuestEvent event, {int target = 1, int progress = 0, bool claimed = false}) =>
    QuestItem(id: id, event: event, target: target, progress: progress, claimed: claimed);

QuestState questState({
  List<QuestItem>? items,
  QuestItem? bonus,
  QuestItem? weekly,
  bool chestOpened = false,
  bool chestDoubled = false,
  String? dayKey,
}) => QuestState(
  dayKey: dayKey ?? economyDayKey(DateTime.now()),
  items:
      items ??
      <QuestItem>[
        questItem('set_wall', QuestEvent.setWallpaper),
        questItem('fav_3', QuestEvent.favourite, target: 3, progress: 1),
        questItem('wotd_view', QuestEvent.viewWotd),
      ],
  bonus: bonus ?? questItem('watch_ad', QuestEvent.watchAd),
  chestOpened: chestOpened,
  chestDoubled: chestDoubled,
  weekKey: '2026-W42',
  weekly: weekly ?? questItem('weekly_set_5', QuestEvent.setWallpaper, target: 5, progress: 2),
);
