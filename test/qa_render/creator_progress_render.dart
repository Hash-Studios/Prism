@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/rewards/domain/creator_progress.dart';
import 'package:Prism/features/rewards/domain/rank_progress.dart';
import 'package:Prism/features/rewards/views/widgets/creator_progress_card.dart';
import 'package:Prism/features/rewards/views/widgets/rank_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'qa_harness.dart';

CreatorProgress _progress({bool zero = false}) => CreatorProgress(
  trackedSince: DateTime.utc(2026, 10, 2),
  approvedWalls: zero ? 0 : 3,
  uniqueMembers: zero ? 0 : 12,
  awardedIds: zero ? <String>{} : <String>{'approved_1', 'members_1', 'members_10'},
  milestones: const <CreatorMilestone>[
    CreatorMilestone(id: 'approved_1', metric: CreatorMetric.approvedWalls, target: 1, xp: 50),
    CreatorMilestone(id: 'approved_5', metric: CreatorMetric.approvedWalls, target: 5, xp: 100),
    CreatorMilestone(id: 'members_1', metric: CreatorMetric.uniqueMembers, target: 1, xp: 25),
    CreatorMilestone(id: 'members_10', metric: CreatorMetric.uniqueMembers, target: 10, xp: 50),
    CreatorMilestone(id: 'members_25', metric: CreatorMetric.uniqueMembers, target: 25, xp: 100),
  ],
  weeks: <CreatorWeek>[
    if (!zero) const CreatorWeek(weekKey: '2026-W42', approvedWalls: 2, newMembers: 7, xp: 50),
    if (!zero) const CreatorWeek(weekKey: '2026-W41', approvedWalls: 1, newMembers: 5, xp: 75),
  ],
);

void main() {
  setUpAll(() async {
    registerFallbackValue(const ShopRoute());
    if (qaRender) await loadFonts();
  });

  for (final String name in <String>['creator_progress', 'creator_zero', 'creator_unknown', 'creator_large_text']) {
    qaScreen(name, (QaShot shot) async {
      final bool large = name == 'creator_large_text';
      if (large) shot.tester.view.physicalSize = const Size(960, 2800);
      final CreatorProgressState state = name == 'creator_unknown'
          ? const CreatorProgressState()
          : CreatorProgressState(
              progress: _progress(zero: name == 'creator_zero'),
              status: CreatorProgressStatus.loaded,
            );
      await shot.pump(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: Scaffold(
              appBar: AppBar(title: const Text('Rewards')),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      if (!large) ...<Widget>[
                        XpProgressCard(
                          progress: RankProgress(
                            xp: 1240,
                            owned: <String>{'glow_aurora'},
                            config: EconomyConfig.defaults,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      CreatorProgressView(state: state, now: DateTime.utc(2026, 10, 18), onRefresh: () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await shot.save(name);
      if (name == 'creator_progress') {
        await shot.tester.ensureVisible(find.text('What counts & history'));
        await shot.tester.tap(find.text('What counts & history'));
        await shot.settle();
        await shot.tester.drag(find.byType(SingleChildScrollView), const Offset(0, -550));
        await shot.settle();
        await shot.save('creator_progress_details');
      }
    });
  }
}
