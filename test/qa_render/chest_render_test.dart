@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/views/widgets/chest_art.dart';
import 'package:Prism/features/quests/views/widgets/chest_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'qa_harness.dart';

Future<void> _openSheet(QaShot shot) async {
  await shot.pump(
    Scaffold(
      body: Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => showChestSheet(
            context,
            const ChestResult(ChestOutcome.opened, coins: 12, doubled: true, itemId: 'frame_ring'),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await shot.tester.tap(find.text('open'));
  await shot.tester.pump();
  await shot.tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
}

void main() {
  setUpAll(() async {
    registerFallbackValue(const ShopRoute());
    if (qaRender) await loadFonts();
  });

  qaScreen('chest_states', height: 600, (QaShot shot) async {
    await shot.pump(
      const Scaffold(
        body: Center(
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: <Widget>[
              ChestArt(size: 150, locked: true),
              ChestArt(size: 150, glow: 1),
              ChestArt(size: 150, lid: 0.35),
              ChestArt(size: 150, lid: 0.7, glow: 1),
              ChestArt(size: 150, lid: 1, glow: 1),
              ChestArt(size: 150, lid: 1),
            ],
          ),
        ),
      ),
    );
    await shot.save('chest_states');
  });

  qaScreen('chest_board_size', height: 300, (QaShot shot) async {
    await shot.pump(
      const Scaffold(
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 16,
            children: <Widget>[
              ChestArt(size: 88, locked: true),
              ChestArt(size: 88, glow: 0.8),
              ChestArt(size: 88, lid: 1),
            ],
          ),
        ),
      ),
    );
    await shot.save('chest_board_size');
  });

  qaScreen('chest_live_ready', height: 300, (QaShot shot) async {
    await shot.pump(
      const Scaffold(
        body: Center(child: LiveChest(stage: ChestStage.ready, size: 160)),
      ),
    );
    // The mount already ran 1500 ms of the 2400 ms cycle, so 1600 ms more lands 700 ms into a cycle, mid wobble.
    await shot.tester.pump(const Duration(milliseconds: 1600));
    await shot.save('chest_live_ready');
  });

  qaScreen('chest_sheet_mid', (QaShot shot) async {
    await _openSheet(shot);
    await shot.tester.pump(const Duration(milliseconds: 520));
    await shot.save('chest_sheet_mid');
  });

  qaScreen('chest_sheet_open', (QaShot shot) async {
    await _openSheet(shot);
    await shot.settle(frames: 10);
    await shot.save('chest_sheet_open');
  });
}
