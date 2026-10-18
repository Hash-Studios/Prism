@Tags(<String>['qa_render'])
library;

import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/features/spin_wheel/views/pages/spin_wheel_page.dart';
import 'package:Prism/features/spin_wheel/views/widgets/spin_wheel_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/quests/fake_quests_repository.dart';
import 'coin_economy_render_test.dart' show registerRewardsDeps;
import 'qa_harness.dart';

const SpinWheelStatus _freeStatus = SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 5, price: 10);
const SpinWheelStatus _paidStatus = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 4, price: 10);
const SpinWheelStatus _cappedStatus = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 0, price: 10);

const int _startBalance = 340;

SpinWon _won(int segment, {int coins = 0, int xp = 0, String? itemId, int cost = 0, SpinWheelStatus? status}) =>
    SpinWon(
      win: WheelWin(segment: segment, coins: coins, xp: xp, itemId: itemId),
      cost: cost,
      balance: _startBalance - cost + coins,
      segments: defaultWheel,
      status: status ?? _paidStatus,
    );

/// Pumps [frames] frames of [step] each, so the ticker runs the wheel.
Future<void> _run(QaShot shot, {required int frames, Duration step = const Duration(milliseconds: 16)}) async {
  for (int i = 0; i < frames; i++) {
    await shot.tester.pump(step);
  }
}

/// Mounts the page with a spin that answers when the returned completer completes.
Future<Completer<SpinWheelResult>> _mount(QaShot shot, SpinWheelStatus status) async {
  final Completer<SpinWheelResult> reply = Completer<SpinWheelResult>();
  CoinsService.instance.spinWheelNotifier.value = status;
  await shot.pump(SpinWheelPage(spin: ({required int maxCost}) => reply.future));
  return reply;
}

Future<void> _tapSpin(QaShot shot, {int spinFrames = 0}) async {
  await shot.tester.tap(find.text('SPIN'));
  await shot.tester.pump();
  await _run(shot, frames: spinFrames);
}

/// Replies with [result] and runs the wheel until it has landed and the result has settled.
Future<void> _land(QaShot shot, Completer<SpinWheelResult> reply, SpinWheelResult result) async {
  reply.complete(result);
  await shot.tester.pump();
  await _run(shot, frames: 170, step: const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() {
    registerFallbackValue(WallpaperDetailRoute());
  });
  setUpAll(loadFonts);

  qaScreen('machine_idle_pro', pro: true, (QaShot shot) async {
    await _mount(shot, _freeStatus);
    await shot.save('machine_idle_pro');
  });

  qaScreen('machine_idle_free', (QaShot shot) async {
    await _mount(shot, _paidStatus);
    await shot.save('machine_idle_free');
  });

  qaScreen('machine_midspin', pro: true, (QaShot shot) async {
    await _mount(shot, _freeStatus);
    await _tapSpin(shot, spinFrames: 75);
    await shot.save('machine_midspin');
  });

  qaScreen('machine_landed_coin', pro: true, (QaShot shot) async {
    final Completer<SpinWheelResult> reply = await _mount(shot, _freeStatus);
    await _tapSpin(shot, spinFrames: 60);
    await _land(shot, reply, _won(4, coins: 20, status: _paidStatus));
    await shot.settle(frames: 4);
    await shot.save('machine_landed_coin');
  });

  qaScreen('machine_jackpot', (QaShot shot) async {
    final Completer<SpinWheelResult> reply = await _mount(shot, _paidStatus);
    await _tapSpin(shot, spinFrames: 60);
    reply.complete(_won(3, coins: 100, cost: 10));
    await shot.tester.pump();
    // Run until the result shows, then catch the coin burst part way through its 700 ms.
    for (int i = 0; i < 300 && find.text('Jackpot. Added to your balance').evaluate().isEmpty; i++) {
      await shot.tester.pump(const Duration(milliseconds: 50));
    }
    await _run(shot, frames: 11, step: const Duration(milliseconds: 20));
    await shot.save('machine_jackpot_burst');
    await shot.settle();
    await shot.save('machine_jackpot');
  });

  qaScreen('machine_small_coin', (QaShot shot) async {
    final Completer<SpinWheelResult> reply = await _mount(shot, _paidStatus);
    await _tapSpin(shot, spinFrames: 60);
    await _land(shot, reply, _won(5, coins: 2, cost: 10));
    await shot.settle(frames: 4);
    await shot.save('machine_small_coin');
  });

  qaScreen('machine_cosmetic', (QaShot shot) async {
    final Completer<SpinWheelResult> reply = await _mount(shot, _paidStatus);
    await _tapSpin(shot, spinFrames: 60);
    await _land(shot, reply, _won(7, itemId: 'frame_aurora', cost: 10));
    await shot.settle(frames: 4);
    await shot.save('machine_cosmetic');
  });

  qaScreen('machine_cosmetic_fallback', (QaShot shot) async {
    final Completer<SpinWheelResult> reply = await _mount(shot, _paidStatus);
    await _tapSpin(shot, spinFrames: 60);
    await _land(shot, reply, _won(7, coins: 50, cost: 10));
    await shot.settle(frames: 4);
    await shot.save('machine_cosmetic_fallback');
  });

  qaScreen('machine_short', (QaShot shot) async {
    CoinsService.instance.balanceNotifier.value = 4;
    await _mount(shot, _paidStatus);
    await shot.save('machine_short');
  });

  qaScreen('machine_capped', pro: true, (QaShot shot) async {
    await _mount(shot, _cappedStatus);
    await shot.save('machine_capped');
  });

  // An iPhone SE sized screen: the wheel shrinks to fit and nothing scrolls or overflows.
  qaScreen('machine_small_screen', height: 667, (QaShot shot) async {
    final Completer<SpinWheelResult> reply = await _mount(shot, _paidStatus);
    await shot.save('machine_small_idle');
    await _tapSpin(shot, spinFrames: 60);
    await _land(shot, reply, _won(4, coins: 20, cost: 10));
    await shot.settle(frames: 4);
    await shot.save('machine_small_landed');
  });

  qaScreen('machine_odds', pro: true, (QaShot shot) async {
    await _mount(shot, _freeStatus);
    await shot.tester.tap(find.text('See the odds'));
    await shot.settle();
    await shot.save('machine_odds');
  });

  qaScreen('spin_card_states', height: 360, (QaShot shot) async {
    CoinsService.instance.spinWheelNotifier.value = _freeStatus;
    await shot.pump(
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(PrismSpace.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SpinWheelCard(status: ValueNotifier<SpinWheelStatus>(_freeStatus)),
              const SizedBox(height: PrismSpace.sm),
              SpinWheelCard(status: ValueNotifier<SpinWheelStatus>(_paidStatus)),
              const SizedBox(height: PrismSpace.sm),
              SpinWheelCard(status: ValueNotifier<SpinWheelStatus>(_cappedStatus)),
            ],
          ),
        ),
      ),
    );
    await shot.save('spin_card_states');
  });

  for (final bool pro in <bool>[true, false]) {
    qaScreen(
      pro ? 'rewards_spin_pro' : 'rewards_spin_free',
      pro: pro,
      setUpExtra: () {
        CoinsService.instance.spinWheelNotifier.value = pro ? _freeStatus : _paidStatus;
        registerRewardsDeps(quests: questState(bonus: questItem('pro_spin', QuestEvent.proSpin)));
      },
      (QaShot shot) async {
        await shot.pump(const RewardsPage(showBack: false));
        await shot.save(pro ? 'rewards_spin_pro' : 'rewards_spin_free');
        // The spin card sits below the Today card: scroll it to the top of the screen.
        final Finder card = find.text('Spin the wheel');
        await shot.tester.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
        await shot.settle(frames: 2);
        await Scrollable.ensureVisible(shot.tester.element(card), alignment: 0.05);
        await shot.settle(frames: 2);
        await shot.save(pro ? 'rewards_spin_pro_card' : 'rewards_spin_free_card');
      },
    );
  }
}
