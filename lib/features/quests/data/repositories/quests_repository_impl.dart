import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/quests/domain/repositories/quests_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: QuestsRepository)
class QuestsRepositoryImpl implements QuestsRepository {
  CoinsService get _coins => CoinsService.instance;

  @override
  Stream<QuestState?> watchQuests() => _watch(_coins.questsNotifier);

  @override
  Stream<List<QuestAward>> watchAwards() => _watch(_coins.questAwardsNotifier);

  @override
  Future<void> refresh() => _coins.progressQuest(null);

  @override
  void consumeAwards() => _coins.consumeQuestAwards();

  Stream<T> _watch<T>(ValueListenable<T> source) {
    late final StreamController<T> controller;
    void push() => controller.add(source.value);
    controller = StreamController<T>(
      onListen: () {
        controller.add(source.value);
        source.addListener(push);
      },
      onCancel: () => source.removeListener(push),
    );
    return controller.stream;
  }
}
