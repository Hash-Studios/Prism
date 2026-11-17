import 'dart:math';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/ranking_rules.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';
import 'ranking_golden_fixture.dart';

/// Ranked ids from origin/master (6b733ee4e) for the fixture in ranking_golden_fixture.dart.
const Map<FeedMix, List<String>> _masterOrder = <FeedMix, List<String>>{
  FeedMix.familiar: <String>[
    'city-7,city-12,city-2,space-13,space-6,space-8,city-6,nature-13,wh4,wh1,wh5,city-13,city-5,space-7,space-0,nature-9',
    'city-11,space-12,space-1,city-15,city-1,space-14,space-10,nature-8,wh0,city-9,space-3,city-10,space-11,city-8,space-9,nature-6',
    'city-3,city-14,space-5,city-4,space-15,nature-12,space-4,nature-1,nature-2,space-2,wh3,wh7,nature-11,nature-15,nature-10,nature-14',
  ],
  FeedMix.balanced: <String>[
    'city-7,city-12,city-2,space-13,nature-13,space-6,space-8,city-6,wh4,nature-9,wh1,wh5,city-13,city-5,nature-14,space-7',
    'space-12,city-8,city-15,space-10,nature-12,city-10,space-2,city-14,space-0,nature-7,space-1,wh0,space-11,city-9,nature-8,city-1',
    'city-11,city-3,space-14,space-15,nature-6,city-4,space-5,space-4,nature-1,wh3,space-9,nature-0,wh7,nature-2,nature-10,space-3',
  ],
  FeedMix.adventurous: <String>[
    'city-7,city-12,nature-13,city-2,space-13,nature-9,space-6,space-8,nature-14,city-6,wh4,wh3,wh1,wh5,wh7,city-13',
    'city-8,space-7,nature-6,space-0,city-4,nature-1,city-15,space-2,nature-11,city-11,space-10,nature-12,wh0,city-10,nature-7,space-12',
    'city-5,city-1,nature-0,city-3,space-9,nature-2,space-11,space-1,nature-4,city-14,city-9,nature-15,space-3,space-5,nature-8,space-15',
  ],
};

String _order(FeedMix mix, RankingRules rules, List<TasteSignal> signals) => goldenOrder(
  (signals) => TasteProfile.build(
    interests: const <String>['space'],
    following: const <String>['city-2@g.test'],
    signals: signals,
    now: goldenNow,
    rules: rules,
  ),
  ({required candidates, required profile, required recentShows, required excludedKeys, required random}) =>
      const PersonalizedRankingService()
          .rank(
            candidates: candidates,
            profile: profile,
            recentShows: recentShows,
            excludedKeys: excludedKeys,
            mix: mix,
            random: random,
            now: goldenNow,
            limit: 16,
            rules: rules,
          )
          .usedKeys,
  signals,
);

List<TasteSignal> _withNewKinds() => <TasteSignal>[
  ...goldenSignals(),
  TasteSignal(action: TasteAction.share, at: goldenNow, terms: const <String>['nature'], creator: 'nature-0@g.test'),
  TasteSignal(action: TasteAction.folderAdd, at: goldenNow, terms: const <String>['cars'], creator: 'cars-1@g.test'),
  for (int i = 0; i < 20; i++)
    TasteSignal(action: TasteAction.scrolledPast, at: goldenNow, terms: const <String>['city'], wallKey: 'k$i'),
];

TasteSignal _signal(TasteAction action, List<String> terms, {int daysAgo = 0, String? creator, String? key}) =>
    TasteSignal(
      action: action,
      at: goldenNow.subtract(Duration(days: daysAgo)),
      terms: terms,
      creator: creator,
      wallKey: key,
    );

const Set<String> _pairs = <String>{'city-0', 'city-1', 'city-2', 'city-3'};

void main() {
  group('rules off', () {
    for (final FeedMix mix in FeedMix.values) {
      test('gives the master order exactly (${mix.name})', () {
        expect(_order(mix, RankingRules.legacy, goldenSignals()).split('\n'), _masterOrder[mix]);
      });

      test('ignores share, folder add and scrolled past signals (${mix.name})', () {
        expect(_order(mix, RankingRules.legacy, _withNewKinds()).split('\n'), _masterOrder[mix]);
      });
    }
  });

  group('hard negatives', () {
    final List<TasteSignal> signals = <TasteSignal>[
      for (int i = 0; i < 40; i++) _signal(TasteAction.favourite, const <String>['city']),
      _signal(TasteAction.lessLikeThis, const <String>['cars'], creator: 'cars@g.test'),
    ];

    test('one less-like keeps its force after 40 favourites', () {
      final TasteProfile legacy = TasteProfile.build(
        interests: const <String>[],
        following: const <String>[],
        signals: signals,
        now: goldenNow,
      );
      final TasteProfile hard = TasteProfile.build(
        interests: const <String>[],
        following: const <String>[],
        signals: signals,
        now: goldenNow,
        rules: const RankingRules(hardNegatives: true),
      );
      expect(legacy.termAffinity(const <String>['cars']), closeTo(-0.067, 0.001));
      expect(hard.termAffinity(const <String>['cars']), -2);
      expect(legacy.creatorAffinity('cars@g.test'), closeTo(-1, 0.001));
      expect(hard.creatorAffinity('cars@g.test'), -1);
      expect(hard.termAffinity(const <String>['city']), legacy.termAffinity(const <String>['city']));
    });
  });

  group('new actions', () {
    final List<TasteSignal> signals = <TasteSignal>[
      _signal(TasteAction.share, const <String>['ocean']),
      _signal(TasteAction.folderAdd, const <String>['forest']),
      _signal(TasteAction.open, const <String>['city']),
    ];

    TasteProfile build(RankingRules rules) => TasteProfile.build(
      interests: const <String>[],
      following: const <String>[],
      signals: signals,
      now: goldenNow,
      rules: rules,
    );

    test('share weighs 5 and folder add 4 with the rule on', () {
      final TasteProfile profile = build(const RankingRules(newActions: true));
      expect(profile.terms, <String, double>{'ocean': 5, 'forest': 4, 'city': 1});
    });

    test('both count nothing with the rule off', () {
      expect(build(RankingRules.legacy).terms, <String, double>{'city': 1});
    });
  });

  group('scrolled past', () {
    final List<RankingCandidate> candidates = goldenCandidates();
    String keyOf(String id) => 'https://g.test/$id.jpg';

    test('a wall an earlier load showed and the user never acted on teaches once', () {
      final List<TasteSignal> out = scrolledPastSignals(
        candidates: candidates,
        recentShows: <String, int>{
          keyOf('space-5'): 1,
          keyOf('city-6'): 2,
          keyOf('cars-7'): 1,
          keyOf('nature-8'): 99,
          keyOf('city-9'): 1,
          keyOf('space-10'): 0,
        },
        excludedKeys: <String>{keyOf('cars-7')},
        signaledKeys: <String>{keyOf('city-9')},
        now: goldenNow,
      );
      expect(out.map((s) => s.wallKey), <String>[keyOf('space-5'), keyOf('city-6')]);
      expect(out.first.action, TasteAction.scrolledPast);
      expect(out.first.terms, <String>['space']);
      expect(out.first.creator, 'space-2@g.test');
    });

    test('weighs -0.3 with the rule on and nothing with it off', () {
      final List<TasteSignal> signals = <TasteSignal>[
        _signal(TasteAction.scrolledPast, const <String>['cars']),
      ];
      TasteProfile build(RankingRules rules) => TasteProfile.build(
        interests: const <String>[],
        following: const <String>[],
        signals: signals,
        now: goldenNow,
        rules: rules,
      );
      expect(build(const RankingRules(scrolledPast: true)).terms['cars'], closeTo(-0.3, 1e-9));
      expect(build(RankingRules.legacy).terms, isEmpty);
    });

    test('decays by half in 30 days like every signal', () {
      final TasteProfile profile = TasteProfile.build(
        interests: const <String>[],
        following: const <String>[],
        signals: <TasteSignal>[
          _signal(TasteAction.scrolledPast, const <String>['cars'], daysAgo: 30),
        ],
        now: goldenNow,
        rules: const RankingRules(scrolledPast: true),
      );
      expect(profile.terms['cars'], closeTo(-0.15, 1e-9));
    });
  });

  group('signal store limits', () {
    late TasteSignalStore store;

    setUp(() => store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));

    test('keeps at most 60 scrolled-past signals, the newest ones', () async {
      await store.recordAll(<TasteSignal>[
        for (int i = 0; i < 100; i++)
          _signal(TasteAction.scrolledPast, const <String>['cars'], daysAgo: 100 - i, key: 'skip$i'),
        for (int i = 0; i < 10; i++) _signal(TasteAction.favourite, const <String>['city'], key: 'fav$i'),
      ]);
      final List<TasteSignal> kept = store.read();
      final List<TasteSignal> skipped = kept.where((s) => s.action == TasteAction.scrolledPast).toList();
      expect(skipped, hasLength(60));
      expect(skipped.first.wallKey, 'skip40');
      expect(kept.where((s) => s.action == TasteAction.favourite), hasLength(10));
    });

    test('scrolled past never pushes the store over 300', () async {
      await store.recordAll(<TasteSignal>[
        for (int i = 0; i < 300; i++) _signal(TasteAction.favourite, const <String>['city'], daysAgo: 1, key: 'fav$i'),
      ]);
      await store.recordAll(<TasteSignal>[
        _signal(TasteAction.scrolledPast, const <String>['cars'], key: 'skip'),
      ]);
      final List<TasteSignal> kept = store.read();
      expect(kept, hasLength(300));
      expect(kept.last.wallKey, 'skip');
      expect(kept.first.wallKey, 'fav1');
    });

    test('signaled keys hold every wall with a signal', () async {
      await store.recordAll(<TasteSignal>[
        _signal(TasteAction.open, const <String>['city'], key: 'opened'),
        _signal(TasteAction.scrolledPast, const <String>['cars'], key: 'skipped'),
        _signal(TasteAction.favourite, const <String>['city']),
      ]);
      expect(store.signaledKeys(), <String>{'opened', 'skipped'});
    });
  });

  group('light/dark dedupe', () {
    List<String> rank(RankingRules rules, {Set<String> excluded = const <String>{}}) =>
        const PersonalizedRankingService()
            .rank(
              candidates: goldenCandidates()
                  .where((c) => _pairs.contains(c.item.id) || c.item.id.startsWith('nature'))
                  .toList(),
              profile: TasteProfile.build(
                interests: const <String>['city'],
                following: const <String>[],
                signals: const <TasteSignal>[],
                now: goldenNow,
              ),
              recentShows: const <String, int>{},
              excludedKeys: excluded,
              mix: FeedMix.familiar,
              random: Random(3),
              now: goldenNow,
              limit: 6,
              rules: rules,
            )
            .items
            .map((item) => item.id)
            .toList();

    test('keeps one wall of each pair in a page', () {
      final List<String> legacy = rank(RankingRules.legacy);
      final List<String> deduped = rank(const RankingRules(dedupeVariants: true));
      expect(legacy.where((id) => id == 'city-0' || id == 'city-1'), hasLength(2));
      expect(deduped.where((id) => id == 'city-0' || id == 'city-1'), hasLength(1));
      expect(deduped.where((id) => id == 'city-2' || id == 'city-3'), hasLength(1));
    });

    test('skips the partner of a wall an earlier page showed', () {
      final List<String> deduped = rank(
        const RankingRules(dedupeVariants: true),
        excluded: <String>{'https://g.test/city-0.jpg'},
      );
      expect(deduped, isNot(contains('city-1')));
      expect(rank(RankingRules.legacy, excluded: <String>{'https://g.test/city-0.jpg'}), contains('city-1'));
    });
  });

  group('explore share', () {
    test('the new rules keep the explore slots of each mix', () {
      for (final FeedMix mix in FeedMix.values) {
        final List<String> page = _order(mix, RankingRules.x2026, goldenSignals()).split('\n').first.split(',');
        final int explore = page.where((id) => id.startsWith('nature') || id.startsWith('wh')).length;
        expect(explore, greaterThanOrEqualTo(16 ~/ mix.exploreEvery), reason: mix.name);
      }
    });
  });
}
