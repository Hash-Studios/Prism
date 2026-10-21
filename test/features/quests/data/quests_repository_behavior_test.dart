import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/quests/data/repositories/quests_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_quests_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final coins = CoinsService.instance;

  tearDown(coins.resetSession);

  test('quest subscribers receive current progress, updates and independent cancellation', () async {
    final repository = QuestsRepositoryImpl();
    coins.questsNotifier.value = questState(
      items: <QuestItem>[questItem('fav_3', QuestEvent.favourite, target: 3, progress: 1)],
    );
    final first = <int>[];
    final second = <int>[];
    final one = repository.watchQuests().listen((state) => first.add(state!.items.single.progress));
    final two = repository.watchQuests().listen((state) => second.add(state!.items.single.progress));
    addTearDown(two.cancel);
    await pumpEventQueue();
    await one.cancel();

    coins.questsNotifier.value = questState(
      items: <QuestItem>[questItem('fav_3', QuestEvent.favourite, target: 3, progress: 3)],
    );
    await pumpEventQueue();

    expect(first, <int>[1]);
    expect(second, <int>[1, 3]);
  });

  test('award subscribers see awarded amounts and consuming clears the pending award', () async {
    final repository = QuestsRepositoryImpl();
    coins.questAwardsNotifier.value = const <QuestAward>[QuestAward(id: 'fav_3', coins: 2, xp: 25)];
    final seen = <List<String>>[];
    final subscription = repository.watchAwards().listen(
      (awards) => seen.add(awards.map((award) => '${award.id}:${award.coins}:${award.xp}').toList()),
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    repository.consumeAwards();
    await pumpEventQueue();

    expect(seen, <List<String>>[
      <String>['fav_3:2:25'],
      <String>[],
    ]);
    expect(coins.questAwardsNotifier.value, isEmpty);
  });
}
