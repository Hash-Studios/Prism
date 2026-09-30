import 'dart:math';

import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

/// Where a candidate came from. The prior discounts sources further from the
/// user's own network, like X's out-of-network discount.
enum CandidatePool {
  following(prior: 1),
  taste(prior: 0.9),
  fresh(prior: 0.85),
  gems(prior: 0.85),
  wallhaven(prior: 0.75),
  pexels(prior: 0.7);

  const CandidatePool({required this.prior});

  final double prior;

  bool get isExternal => this == CandidatePool.wallhaven || this == CandidatePool.pexels;
}

class RankingCandidate {
  RankingCandidate({required this.item, required this.pool, List<String> extraTerms = const <String>[]})
    : key = PersonalizedRankingService.canonicalKey(item),
      creator = tasteCreatorOf(item.wallpaperCore),
      terms = <String>{...termsOf(item), ...extraTerms.map((e) => e.toLowerCase())}.toList(growable: false);

  final FeedItemEntity item;
  final CandidatePool pool;
  final String key;
  final String? creator;
  final List<String> terms;

  static List<String> termsOf(FeedItemEntity item) => item.when(
    prism: (_, wall) => tasteTermsOf(wall.core, tags: wall.tags, collections: wall.collections),
    wallhaven: (_, wall) => tasteTermsOf(wall.core, tags: wall.tags),
    pexels: (_, wall) => tasteTermsOf(wall.core),
  );
}

class PersonalizedRankingResult {
  const PersonalizedRankingResult({required this.items, required this.usedKeys, required this.sourceCounts});

  final List<FeedItemEntity> items;
  final List<String> usedKeys;
  final Map<WallpaperSource, int> sourceCounts;
}

/// Scores and mixes feed candidates on device. Stages follow X's home mixer:
/// filter, score (weighted taste affinity x source prior x freshness x
/// impression fatigue x noise), then select with author diversity decay and
/// reserved exploration slots.
class PersonalizedRankingService {
  const PersonalizedRankingService();

  static const double _authorDecay = 0.5;
  static const double _authorFloor = 0.3;
  static const double _fatiguePerShow = 0.4;
  static const double _freshDays = 14;
  static const double _maxExternalShare = 0.5;

  PersonalizedRankingResult rank({
    required List<RankingCandidate> candidates,
    required TasteProfile profile,
    required Map<String, int> recentShows,
    required Set<String> excludedKeys,
    required FeedMix mix,
    required Random random,
    required DateTime now,
    int limit = 24,
  }) {
    final Map<String, _Scored> byKey = <String, _Scored>{};
    for (final RankingCandidate candidate in candidates) {
      if (excludedKeys.contains(candidate.key)) {
        continue;
      }
      final _Scored scored = _score(candidate, profile, recentShows[candidate.key] ?? 0, random, now);
      final _Scored? existing = byKey[candidate.key];
      if (existing == null || scored.score > existing.score) {
        byKey[candidate.key] = scored;
      }
    }

    final List<_Scored> pool = byKey.values.toList()..sort((a, b) => b.score.compareTo(a.score));
    final List<_Scored> selected = <_Scored>[];
    final Map<String, int> perCreator = <String, int>{};
    final int maxExternal = (limit * _maxExternalShare).ceil();
    int external = 0;

    while (selected.length < limit && pool.isNotEmpty) {
      final bool exploreSlot = (selected.length + 1) % mix.exploreEvery == 0;
      final _Scored? pick =
          _best(pool, perCreator, external < maxExternal, onlyExplore: exploreSlot) ??
          _best(pool, perCreator, external < maxExternal) ??
          _best(pool, perCreator, true);
      if (pick == null) {
        break;
      }
      pool.remove(pick);
      selected.add(pick);
      if (pick.candidate.pool.isExternal) {
        external += 1;
      }
      final String? creator = pick.candidate.creator;
      if (creator != null) {
        perCreator[creator] = (perCreator[creator] ?? 0) + 1;
      }
    }

    final List<FeedItemEntity> items = selected.map((e) => e.candidate.item).toList(growable: false);
    return PersonalizedRankingResult(
      items: items,
      usedKeys: selected.map((e) => e.candidate.key).toList(growable: false),
      sourceCounts: <WallpaperSource, int>{
        for (final WallpaperSource source in <WallpaperSource>[
          WallpaperSource.prism,
          WallpaperSource.wallhaven,
          WallpaperSource.pexels,
        ])
          source: items.where((e) => e.source == source).length,
      },
    );
  }

  _Scored _score(RankingCandidate candidate, TasteProfile profile, int shows, Random random, DateTime now) {
    final double taste = profile.termAffinity(candidate.terms);
    final double creator = profile.creatorAffinity(candidate.creator);
    final DateTime? createdAt = candidate.item.wallpaperCore.createdAt;
    final double ageDays = createdAt == null ? double.infinity : now.difference(createdAt).inHours / 24;
    final double freshness = ageDays < _freshDays ? 0.5 * (1 - ageDays / _freshDays) : 0;
    final double base = max(0.05, 1 + 1.5 * taste + creator + freshness);
    final double fatigue = pow(_fatiguePerShow, shows).toDouble();
    final double noise = 0.7 + 0.6 * random.nextDouble();
    return _Scored(
      candidate: candidate,
      score: candidate.pool.prior * base * fatigue * noise,
      explore: taste <= 0 && creator <= 0,
    );
  }

  _Scored? _best(List<_Scored> pool, Map<String, int> perCreator, bool allowExternal, {bool onlyExplore = false}) {
    _Scored? best;
    double bestScore = double.negativeInfinity;
    for (final _Scored entry in pool) {
      if (onlyExplore && !entry.explore) {
        continue;
      }
      if (!allowExternal && entry.candidate.pool.isExternal) {
        continue;
      }
      final String? creator = entry.candidate.creator;
      final int seen = creator == null ? 0 : perCreator[creator] ?? 0;
      final double adjusted = entry.score * ((1 - _authorFloor) * pow(_authorDecay, seen) + _authorFloor);
      if (adjusted > bestScore) {
        bestScore = adjusted;
        best = entry;
      }
    }
    return best;
  }

  static String canonicalKey(FeedItemEntity item) {
    final String normalizedUrl = item.wallpaperCore.fullUrl.trim().toLowerCase();
    if (normalizedUrl.isNotEmpty) {
      return normalizedUrl;
    }
    return '${item.source.wireValue}:${item.id.trim().toLowerCase()}';
  }
}

class _Scored {
  const _Scored({required this.candidate, required this.score, required this.explore});

  final RankingCandidate candidate;
  final double score;
  final bool explore;
}
