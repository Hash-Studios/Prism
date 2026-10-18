import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/rewards/domain/rank_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RankProgress progress(
    int xp, {
    Set<String> owned = const <String>{},
    EconomyConfig config = EconomyConfig.defaults,
  }) => RankProgress(xp: xp, owned: owned, config: config);

  test('rank reward changes to earned at the configured threshold, never to owned', () {
    expect(progress(499).nextReward!.earned, isFalse);
    final RankProgress atSilver = progress(500);
    expect(atSilver.rank.id, 'silver');
    expect(atSilver.nextReward!.item.id, 'glow_aurora');
    expect(atSilver.nextReward!.earned, isTrue);
    expect(atSilver.nextReward!.owned, isFalse);
    expect(progress(500, owned: <String>{'glow_aurora'}).nextReward!.item.id, 'frame_gold');
  });

  test('all crossed rewards remain pending until inventory confirmation', () {
    final RankProgress atTop = progress(9000);
    expect(atTop.rewards.where((RankRewardProgress reward) => reward.earned), hasLength(3));
    expect(atTop.rewards.any((RankRewardProgress reward) => reward.owned), isFalse);
    expect(atTop.nextRank, isNull);
    expect(atTop.rank.progress, 1);
    expect(progress(9000, owned: <String>{'glow_aurora', 'frame_gold', 'glow_prism'}).nextReward, isNull);
  });

  test('next custom rank and next reward are independent', () {
    const EconomyConfig config = EconomyConfig(
      xp: EconomyXp(
        ranks: <RankDef>[
          RankDef(id: 'bronze', min: 0),
          RankDef(id: 'collector', min: 100),
          RankDef(id: 'silver', min: 700),
          RankDef(id: 'gold', min: 2200),
          RankDef(id: 'prism', min: 7000),
          RankDef(id: 'curator', min: 8000),
        ],
      ),
    );
    final RankProgress result = progress(70, config: config);
    expect(result.nextRank!.id, 'collector');
    expect(result.remainingXp, 30);
    expect(result.nextReward!.rank.id, 'silver');
    expect(result.nextReward!.rank.min, 700);
    expect(progress(699, config: config).nextReward!.earned, isFalse);
    expect(progress(700, config: config).nextReward!.earned, isTrue);
    expect(progress(9000, config: config).rank.id, 'curator');
  });

  test('removed reward ranks grant no invented milestones; prior ownership stays confirmed', () {
    const EconomyConfig config = EconomyConfig(
      xp: EconomyXp(
        ranks: <RankDef>[
          RankDef(id: 'starter', min: 0),
          RankDef(id: 'gold', min: 5000),
        ],
      ),
    );
    final RankProgress result = progress(2000, config: config, owned: <String>{'frame_gold', 'glow_aurora'});
    expect(result.rewards, hasLength(1));
    expect(result.rewards.single.owned, isTrue);
    expect(result.rewards.single.earned, isFalse);
    expect(result.nextReward, isNull);
  });
}
