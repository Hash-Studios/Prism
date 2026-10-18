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

    expect(bloc.state.quests?.items.every((QuestItem q) => q.claimed), isTrue);
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

  test('quests from an earlier UTC day are hidden until the server sends today', () async {
    final FakeQuestsRepository repo = FakeQuestsRepository(quests: questState(dayKey: '2020-01-01'));
    final QuestsBloc bloc = QuestsBloc(repo)..add(const QuestsEvent.started());
    await pumpEventQueue();
    expect(bloc.state.quests, isNull);

    repo.quests.value = questState();
    await pumpEventQueue();
    expect(bloc.state.quests, isNotNull);
    await bloc.close();
  });

  test('refreshed syncs again and drops the quests once the day has turned', () async {
    final FakeQuestsRepository repo = FakeQuestsRepository(quests: questState());
    final QuestsBloc bloc = QuestsBloc(repo)..add(const QuestsEvent.started());
    await pumpEventQueue();
    expect(bloc.state.quests, isNotNull);

    bloc.clock = () => DateTime.now().add(const Duration(days: 1));
    bloc.add(const QuestsEvent.refreshed());
    await pumpEventQueue();

    expect(repo.refreshes, 2);
    expect(bloc.state.quests, isNull);
    await bloc.close();
  });
}
