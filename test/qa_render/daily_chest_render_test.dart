@Tags(<String>['qa_render'])
library;

import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/daily_chest/daily_chest.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/views/widgets/today_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/quests/fake_quests_repository.dart';
import 'qa_harness.dart';

/// 18:48 UTC: the next chest is in 5h 12m.
final DateTime _now = DateTime.utc(2026, 10, 18, 18, 48);
final String _today = economyDayKey(_now);

QuestState _quests({int claimed = 0, bool bonusDone = false, bool opened = false}) => questState(
  dayKey: _today,
  items: <QuestItem>[
    questItem('set_wall', QuestEvent.setWallpaper, claimed: claimed > 0, progress: claimed > 0 ? 1 : 0),
    questItem('fav_3', QuestEvent.favourite, target: 3, claimed: claimed > 1, progress: claimed > 1 ? 3 : 1),
    questItem('wotd_view', QuestEvent.viewWotd, claimed: claimed > 2, progress: claimed > 2 ? 1 : 0),
  ],
  bonus: questItem('watch_ad', QuestEvent.watchAd, claimed: bonusDone, progress: bonusDone ? 1 : 0),
  chestOpened: opened,
  chestDoubled: opened && bonusDone,
);

ChestWon _won(int slot, {int coins = 0, int xp = 0, String? itemId, int cost = 8, bool doubled = false}) => ChestWon(
  win: ChestWin(slot: slot, coins: coins, xp: xp, itemId: itemId),
  cost: cost,
  doubled: doubled,
  slots: defaultChest,
);

Future<void> _run(QaShot shot, {required int frames, Duration step = const Duration(milliseconds: 20)}) async {
  for (int i = 0; i < frames; i++) {
    await shot.tester.pump(step);
  }
}

/// Mounts the page with an open function that answers when the returned completer completes.
Future<Completer<DailyChestResult>> _mount(QaShot shot, {QuestState? quests, int balance = 340}) async {
  final Completer<DailyChestResult> reply = Completer<DailyChestResult>();
  await shot.pump(
    DailyChestPage(
      open: ({required int maxCost}) => reply.future,
      quests: ValueNotifier<QuestState?>(quests ?? _quests()),
      balance: ValueNotifier<int>(balance),
      now: () => _now,
      refresh: () async {},
    ),
  );
  return reply;
}

/// Taps Open, answers with [result] and runs the box until the prize has settled.
Future<void> _open(
  QaShot shot,
  Completer<DailyChestResult> reply,
  DailyChestResult result, {
  String label = 'Open',
}) async {
  await shot.tester.tap(find.text(label));
  await shot.tester.pump();
  reply.complete(result);
  await shot.tester.pump();
  await _run(shot, frames: 200, step: const Duration(milliseconds: 25));
  await shot.settle(frames: 2);
}

void main() {
  setUpAll(() {
    registerFallbackValue(WallpaperDetailRoute());
  });
  setUpAll(loadFonts);

  qaScreen('chest_ready_paid', (QaShot shot) async {
    await _mount(shot);
    await shot.save('chest_ready_paid');
  });

  qaScreen('chest_ready_free', (QaShot shot) async {
    await _mount(shot, quests: _quests(claimed: 3, bonusDone: true));
    await shot.save('chest_ready_free');
  });

  qaScreen('chest_charging', (QaShot shot) async {
    final Completer<DailyChestResult> reply = await _mount(shot);
    await shot.tester.tap(find.text('Open'));
    await shot.tester.pump();
    await _run(shot, frames: 15);
    await shot.save('chest_charging');
    // Let the pending request end so the test leaves no timers behind.
    reply.complete(const ChestRefused(ChestRefusal.insufficientBalance));
    await _run(shot, frames: 40);
  });

  qaScreen('chest_opening', (QaShot shot) async {
    final Completer<DailyChestResult> reply = await _mount(shot);
    await shot.tester.tap(find.text('Open'));
    await shot.tester.pump();
    reply.complete(_won(3, coins: 20));
    await shot.tester.pump();
    // The hold is 600 ms, the burst 267 ms after it. Catch the prize 130 ms into its rise.
    await _run(shot, frames: 45);
    await shot.save('chest_opening');
    await _run(shot, frames: 20);
    await shot.save('chest_opening_late');
    await shot.settle();
  });

  qaScreen('chest_revealed_rare', (QaShot shot) async {
    final Completer<DailyChestResult> reply = await _mount(shot);
    await _open(shot, reply, _won(3, coins: 20));
    await shot.save('chest_revealed_rare');
  });

  qaScreen('chest_revealed_doubled', (QaShot shot) async {
    final Completer<DailyChestResult> reply = await _mount(shot, quests: _quests(claimed: 3, bonusDone: true));
    await _open(shot, reply, _won(3, coins: 40, cost: 0, doubled: true), label: 'Open free');
    await shot.save('chest_revealed_doubled');
  });

  qaScreen('chest_revealed_epic_cosmetic', (QaShot shot) async {
    final Completer<DailyChestResult> reply = await _mount(shot);
    await _open(shot, reply, _won(4, itemId: 'frame_ring'));
    await shot.save('chest_revealed_epic_cosmetic');
  });

  qaScreen('chest_revealed_legendary', (QaShot shot) async {
    final Completer<DailyChestResult> reply = await _mount(shot);
    await shot.tester.tap(find.text('Open'));
    await shot.tester.pump();
    reply.complete(_won(6, coins: 100));
    await shot.tester.pump();
    // Catch the coin burst part way through its 700 ms.
    await _run(shot, frames: 52);
    await shot.save('chest_legendary_burst');
    await _run(shot, frames: 160, step: const Duration(milliseconds: 25));
    await shot.settle(frames: 2);
    await shot.save('chest_revealed_legendary');
  });

  qaScreen('chest_revealed_xp', (QaShot shot) async {
    final Completer<DailyChestResult> reply = await _mount(shot);
    await _open(shot, reply, _won(2, xp: 25));
    await shot.save('chest_revealed_xp');
  });

  qaScreen('chest_revealed_fallback', (QaShot shot) async {
    final Completer<DailyChestResult> reply = await _mount(shot);
    await _open(shot, reply, _won(4, coins: 25));
    await shot.save('chest_revealed_fallback');
  });

  qaScreen('chest_spent', (QaShot shot) async {
    await _mount(shot, quests: _quests(claimed: 3, opened: true));
    await shot.save('chest_spent');
  });

  qaScreen('chest_get_coins', (QaShot shot) async {
    await _mount(shot, balance: 4);
    await shot.save('chest_get_coins');
  });

  qaScreen('chest_odds', (QaShot shot) async {
    await _mount(shot);
    await shot.tester.tap(find.text('See the odds'));
    await shot.settle();
    await shot.save('chest_odds');
  });

  // An iPhone SE sized screen: the box shrinks to fit and the prize card still clears the title and the button.
  qaScreen('chest_small_screen', height: 667, (QaShot shot) async {
    final Completer<DailyChestResult> reply = await _mount(shot);
    await shot.save('chest_small_ready');
    await _open(shot, reply, _won(4, itemId: 'frame_ring'));
    await shot.save('chest_small_revealed');
  });

  qaScreen(
    'chest_today_row',
    height: 2060,
    setUpExtra: () {
      final List<QuestState> states = <QuestState>[_quests(), _quests(claimed: 3), _quests(claimed: 3, opened: true)];
      int next = 0;
      getIt.registerFactory<QuestsBloc>(() => QuestsBloc(FakeQuestsRepository(quests: states[next++ % 3])));
    },
    (QaShot shot) async {
      await shot.pump(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(PrismSpace.page),
            child: Builder(
              builder: (BuildContext context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Paid', style: PrismTextStyles.caption(context)),
                  const SizedBox(height: PrismSpace.xxs),
                  const TodayCard(),
                  Text('Free', style: PrismTextStyles.caption(context)),
                  const SizedBox(height: PrismSpace.xxs),
                  const TodayCard(),
                  Text('Opened', style: PrismTextStyles.caption(context)),
                  const SizedBox(height: PrismSpace.xxs),
                  const TodayCard(),
                ],
              ),
            ),
          ),
        ),
      );
      await shot.save('chest_today_row');
    },
  );
}
