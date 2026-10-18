@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/views/widgets/today_card.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/quests/fake_quests_repository.dart';
import 'coin_economy_render_test.dart' show allDone, registerRewardsDeps;
import 'qa_harness.dart';

const double _boardHeight = 1300;

void Function() _withQuests(QuestState quests) =>
    () => getIt.registerFactory<QuestsBloc>(() => QuestsBloc(FakeQuestsRepository(quests: quests)));

QuestState _proReady() => questState(items: allDone().items, bonus: questItem('pro_spin', QuestEvent.proSpin));

Future<void> _board(QaShot shot, String name) async {
  await shot.pump(
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PrismSpace.page),
        child: TodayCard(onOpenSpin: () {}),
      ),
    ),
  );
  await shot.save(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(WallpaperDetailRoute());
  });
  setUpAll(loadFonts);

  group('quests render', () {
    qaScreen('quests_locked', height: _boardHeight, setUpExtra: _withQuests(questState()), (QaShot shot) async {
      await _board(shot, 'quests_locked');
    });

    qaScreen('quests_ready', height: _boardHeight, setUpExtra: _withQuests(allDone()), (QaShot shot) async {
      await _board(shot, 'quests_ready');
    });

    qaScreen(
      'quests_doubled',
      height: _boardHeight,
      setUpExtra: _withQuests(allDone(chestOpened: true, chestDoubled: true)),
      (QaShot shot) async {
        await _board(shot, 'quests_doubled');
      },
    );

    qaScreen('quests_pro_ready', pro: true, height: _boardHeight, setUpExtra: _withQuests(_proReady()), (
      QaShot shot,
    ) async {
      await _board(shot, 'quests_pro_ready');
    });

    qaScreen('rewards_quests', height: _boardHeight, setUpExtra: () => registerRewardsDeps(quests: allDone()), (
      QaShot shot,
    ) async {
      await shot.pump(const RewardsPage(showBack: false));
      final Finder board = find.text('Daily quests');
      await shot.tester.scrollUntilVisible(board, 300, scrollable: find.byType(Scrollable).first);
      await shot.settle(frames: 2);
      await Scrollable.ensureVisible(shot.tester.element(board), alignment: 0.02);
      await shot.settle(frames: 2);
      await shot.save('rewards_quests');
    });
  });
}
