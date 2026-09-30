import 'dart:math';

import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItemEntity _prism(String id, {required String category, String? creator}) {
  return FeedItemEntity.prism(
    id: id,
    wallpaper: PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: 'https://example.com/$id.jpg',
        thumbnailUrl: 'https://example.com/$id-t.jpg',
        authorEmail: creator ?? '$id@a.com',
        category: category,
      ),
    ),
  );
}

FeedItemEntity _wallhaven(String id) {
  return FeedItemEntity.wallhaven(
    id: id,
    wallpaper: WallhavenWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.wallhaven,
        fullUrl: 'https://example.com/$id.jpg',
        thumbnailUrl: 'https://example.com/$id-t.jpg',
        authorName: 'wh$id',
      ),
    ),
  );
}

RankingCandidate _cand(FeedItemEntity item, [CandidatePool pool = CandidatePool.taste]) =>
    RankingCandidate(item: item, pool: pool);

void main() {
  const PersonalizedRankingService service = PersonalizedRankingService();
  final DateTime now = DateTime.utc(2026, 6);
  final TasteProfile spaceProfile = TasteProfile.build(
    interests: <String>['space'],
    following: const <String>[],
    signals: const [],
    now: now,
  );

  PersonalizedRankingResult rank(
    List<RankingCandidate> candidates, {
    Map<String, int> recentShows = const <String, int>{},
    Set<String> excluded = const <String>{},
    FeedMix mix = FeedMix.familiar,
    int limit = 8,
  }) => service.rank(
    candidates: candidates,
    profile: spaceProfile,
    recentShows: recentShows,
    excludedKeys: excluded,
    mix: mix,
    random: Random(1),
    now: now,
    limit: limit,
  );

  List<RankingCandidate> spaceAndCats() => <RankingCandidate>[
    for (int i = 0; i < 12; i++) _cand(_prism('s$i', category: 'space')),
    for (int i = 0; i < 12; i++) _cand(_prism('c$i', category: 'cats')),
  ];

  int count(PersonalizedRankingResult r, String prefix) => r.items.where((e) => e.id.startsWith(prefix)).length;

  test('excluded keys are never returned', () {
    final List<RankingCandidate> candidates = spaceAndCats();
    final Set<String> excluded = <String>{for (int i = 0; i < 6; i++) candidates[i].key};

    final PersonalizedRankingResult result = rank(candidates, excluded: excluded, limit: 24);

    expect(result.items, hasLength(18));
    expect(result.usedKeys.toSet().intersection(excluded), isEmpty);
  });

  test('taste wins the non-exploration slots', () {
    final PersonalizedRankingResult result = rank(spaceAndCats());

    expect(result.items, hasLength(8));
    expect(count(result, 's'), greaterThanOrEqualTo(6));
  });

  test('adventurous mix reserves every third slot for outside taste', () {
    final PersonalizedRankingResult result = rank(spaceAndCats(), mix: FeedMix.adventurous, limit: 9);

    expect(count(result, 'c'), greaterThanOrEqualTo(3));
  });

  test('a repeatedly shown wall ranks below an equal fresh one', () {
    final RankingCandidate a = _cand(_prism('a', category: 'space'));
    final RankingCandidate b = _cand(_prism('b', category: 'space'));

    final PersonalizedRankingResult result = rank(
      <RankingCandidate>[a, b],
      recentShows: <String, int>{a.key: 3},
      limit: 2,
    );

    expect(result.items.map((e) => e.id), <String>['b', 'a']);
  });

  test('one creator holds at most 3 of 6 slots', () {
    final List<RankingCandidate> candidates = <RankingCandidate>[
      for (int i = 0; i < 10; i++) _cand(_prism('x$i', category: 'space', creator: 'x@a.com')),
      for (int i = 0; i < 10; i++) _cand(_prism('o$i', category: 'space')),
    ];

    final PersonalizedRankingResult result = rank(candidates, limit: 6);

    expect(result.items, hasLength(6));
    expect(count(result, 'x'), lessThanOrEqualTo(3));
  });

  test('external sources fill at most half of the slots', () {
    final List<RankingCandidate> candidates = <RankingCandidate>[
      for (int i = 0; i < 20; i++) _cand(_wallhaven('w$i'), CandidatePool.wallhaven),
      for (int i = 0; i < 4; i++) _cand(_prism('g$i', category: 'art'), CandidatePool.gems),
    ];

    final PersonalizedRankingResult result = rank(candidates, mix: FeedMix.balanced);

    expect(result.items, hasLength(8));
    expect(result.sourceCounts[WallpaperSource.wallhaven], lessThanOrEqualTo(4));
  });

  test('the same wall from two pools is returned once', () {
    final FeedItemEntity item = _prism('d', category: 'space');

    final PersonalizedRankingResult result = rank(<RankingCandidate>[_cand(item), _cand(item, CandidatePool.fresh)]);

    expect(result.items.map((e) => e.id), <String>['d']);
  });

  test('a hidden wall is excluded even when it is the only candidate', () {
    final RankingCandidate hidden = _cand(_prism('hidden', category: 'space'));

    final PersonalizedRankingResult result = rank(
      <RankingCandidate>[hidden],
      recentShows: <String, int>{hidden.key: 99},
      limit: 1,
    );

    expect(result.items, isEmpty);
  });

  test('disliked walls are not treated as exploration candidates', () {
    const TasteProfile profile = TasteProfile(
      terms: <String, double>{'space': 4, 'cats': -0.1},
      creators: <String, double>{},
    );
    final PersonalizedRankingResult result = service.rank(
      candidates: <RankingCandidate>[
        for (int i = 0; i < 23; i++) _cand(_prism('positive$i', category: 'space')),
        _cand(_prism('disliked', category: 'cats'), CandidatePool.following),
      ],
      profile: profile,
      recentShows: const <String, int>{},
      excludedKeys: const <String>{},
      mix: FeedMix.balanced,
      random: Random(1),
      now: now,
    );

    expect(result.items, hasLength(24));
    expect(result.items[4].id, isNot('disliked'));
  });
}
