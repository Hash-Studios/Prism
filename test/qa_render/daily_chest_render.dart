@Tags(<String>['qa_render'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/daily_chest/daily_chest.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/views/widgets/today_card.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/quests/fake_quests_repository.dart';
import '../support/coins_test_backend.dart';
import 'qa_harness.dart';
import 'qa_images.dart';

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

/// What the server replies with: every fresh open grants the chest's 10 XP (`xpAwarded`), whatever the prize.
ChestWon _won(int slot, {int coins = 0, int xp = 10, String? itemId, int cost = 8, bool doubled = false}) => ChestWon(
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
  final ValueNotifier<int> coins = ValueNotifier<int>(balance);
  await shot.pump(
    DailyChestPage(
      // Like the coins service, a win moves the balance before the reply reaches the page.
      open: ({required int maxCost}) => reply.future.then((DailyChestResult result) {
        if (result is ChestWon) coins.value += result.win.coins - result.cost;
        return result;
      }),
      quests: ValueNotifier<QuestState?>(quests ?? _quests()),
      balance: coins,
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

/// One captured frame per 1/30 s of app time, and the moment the fake `open` answers after the tap.
const Duration _reelStep = Duration(microseconds: 33333);
const Duration _reelReply = Duration(milliseconds: 400);

/// Opens the chest once in the dark theme and writes a 390x844 PNG per frame to
/// `build/qa_render/daily_chest_flow/[name]`. It starts with 0.6 s of idle box and ends 1 s after the Done button
/// appears. Returns the frame count.
Future<int> _film(QaShot shot, String name, ChestWon won) async {
  final WidgetTester tester = shot.tester;
  final Directory dir = Directory('build/qa_render/daily_chest_flow/$name');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  int count = 0;
  Future<void> frame() async {
    final RenderRepaintBoundary boundary = shot.boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final File file = File('${dir.path}/frame_${(count++).toString().padLeft(4, '0')}.png');
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage();
      final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pump(_reelStep);
  }

  final Completer<DailyChestResult> reply = await _mount(shot);
  for (int i = 0; i < 18; i++) {
    await frame();
  }
  await tester.tap(find.text('Open'));
  await tester.pump();
  expect(find.text('332'), findsOneWidget, reason: 'the price leaves the pill at the tap');
  Duration sinceTap = Duration.zero;
  int tail = 0;
  while (tail < 30) {
    await frame();
    sinceTap += _reelStep;
    if (!reply.isCompleted && sinceTap >= _reelReply) reply.complete(won);
    if (find.text('Done').evaluate().isNotEmpty) tail++;
    expect(sinceTap, lessThan(const Duration(seconds: 8)), reason: 'the chest never showed its prize');
  }
  return count;
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

  group('chest open flow', skip: !qaRender, () {
    for (final (String name, ChestWon won, int balance) in <(String, ChestWon, int)>[
      ('rare', _won(3, coins: 20), 352),
      ('legendary', _won(6, coins: 100), 432),
    ]) {
      testWidgets('$name (dark)', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final CoinsTestBackend backend = CoinsTestBackend();
        await backend.install();
        seedUser(pro: false);
        await QaImages.install(tester);
        addTearDown(() async {
          QaImages.uninstall();
          resetUser();
          await getIt.reset();
        });
        final int frames = await _film(QaShot(tester, Brightness.dark, kDarkTheme, backend), name, won);
        expect(find.text('$balance'), findsOneWidget, reason: 'the pill shows the balance with the prize');
        expect(find.text('+10 XP'), findsOneWidget, reason: 'the card shows the XP the open granted');
        debugPrint('chest open flow $name: $frames frames at 30 fps');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
