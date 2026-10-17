import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_quests_repository.dart';

void main() {
  test('started syncs and follows the quest and award streams', () async {
    final FakeQuestsRepository repo = FakeQuestsRepository(quests: questState());
    final QuestsBloc bloc = QuestsBloc(repo)..add(const QuestsEvent.started());
    await pumpEventQueue();

    expect(repo.refreshes, 1);
    expect(bloc.state.quests?.items, hasLength(3));

    final QuestState done = questState(
      items: <QuestItem>[for (final QuestItem q in questState().items) questItem(q.id, q.event, claimed: true)],
    );
    repo.quests.value = done;
    repo.awards.value = const <QuestAward>[QuestAward(id: 'set_wall', coins: 2, xp: 25)];
    await pumpEventQueue();

    expect(bloc.state.quests?.chestReady, isTrue);
    expect(bloc.state.awards.single.id, 'set_wall');
    await bloc.close();
  });

  test('awardsShown consumes the awards', () async {
    final FakeQuestsRepository repo = FakeQuestsRepository(quests: questState());
    final QuestsBloc bloc = QuestsBloc(repo)..add(const QuestsEvent.started());
    repo.awards.value = const <QuestAward>[QuestAward(id: 'fav_3', coins: 2, xp: 25)];
    await pumpEventQueue();
    bloc.add(const QuestsEvent.awardsShown());
    await pumpEventQueue();

    expect(repo.consumed, 1);
    expect(bloc.state.awards, isEmpty);
    await bloc.close();
  });

  test('chestOpened stores the result and ignores a second tap while opening', () async {
    final FakeQuestsRepository repo = FakeQuestsRepository(quests: questState());
    repo.pendingOpen = Completer<ChestResult>();
    final QuestsBloc bloc = QuestsBloc(repo);
    bloc
      ..add(const QuestsEvent.chestOpened())
      ..add(const QuestsEvent.chestOpened());
    await pumpEventQueue();
    expect(bloc.state.opening, isTrue);

    repo.pendingOpen!.complete(const ChestResult(ChestOutcome.opened, coins: 12, doubled: true));
    await pumpEventQueue();

    expect(repo.opens, 1);
    expect(bloc.state.opening, isFalse);
    expect(bloc.state.chest?.coins, 12);
    await bloc.close();
  });

  test('a locked chest refreshes the quest state', () async {
    final FakeQuestsRepository repo = FakeQuestsRepository(
      quests: questState(),
      chest: const ChestResult(ChestOutcome.locked),
    );
    final QuestsBloc bloc = QuestsBloc(repo)..add(const QuestsEvent.chestOpened());
    await pumpEventQueue();

    expect(bloc.state.chest?.outcome, ChestOutcome.locked);
    expect(repo.refreshes, 1);
    await bloc.close();
  });
}
