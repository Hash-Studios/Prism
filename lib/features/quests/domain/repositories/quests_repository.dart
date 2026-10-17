import 'package:Prism/core/coins/coins_service.dart';

abstract class QuestsRepository {
  /// Today's quests. Emits the current value first.
  Stream<QuestState?> watchQuests();

  /// Quest items the server just paid. Emits the current value first.
  Stream<List<QuestAward>> watchAwards();

  /// Syncs the quest state with the server.
  Future<void> refresh();

  Future<ChestResult> openChest();

  /// Call after the awards were shown.
  void consumeAwards();
}
