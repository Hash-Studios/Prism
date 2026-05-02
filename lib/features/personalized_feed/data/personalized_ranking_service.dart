import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

class PersonalizedRankingResult {
  const PersonalizedRankingResult({
    required this.items,
    required this.usedKeys,
    required this.sourceCounts,
    this.discoveryCount = 0,
  });

  final List<FeedItemEntity> items;
  final List<String> usedKeys;
  final Map<WallpaperSource, int> sourceCounts;

  /// Number of items that came from the discovery (unfollowed creator) pool.
  final int discoveryCount;
}

class PersonalizedRankingService {
  const PersonalizedRankingService();

  PersonalizedRankingResult rankAndMix({
    required List<FeedItemEntity> creatorItems,
    required List<FeedItemEntity> wallhavenItems,
    required List<FeedItemEntity> pexelsItems,
    List<FeedItemEntity> discoveryItems = const <FeedItemEntity>[],
    required Set<String> blockedKeys,
    required Set<String> interests,
    int limit = 24,
    int creatorTarget = 10,
    int discoveryTarget = 4,
    int wallhavenTarget = 5,
    int pexelsTarget = 5,
  }) {
    final creatorCandidates = _score(creatorItems, sourceBase: 1000, interests: interests, blockedKeys: blockedKeys);
    // Discovery items are Prism-hosted walls from unfollowed creators, scored
    // between followed creators (1000) and external sources (600).
    final discoveryCandidates = _score(discoveryItems, sourceBase: 800, interests: interests, blockedKeys: blockedKeys);
    final wallhavenCandidates = _score(wallhavenItems, sourceBase: 600, interests: interests, blockedKeys: blockedKeys);
    final pexelsCandidates = _score(pexelsItems, sourceBase: 550, interests: interests, blockedKeys: blockedKeys);

    final List<_Ranked> selected = <_Ranked>[];
    final Set<String> selectedKeys = <String>{};
    // Track which keys were filled from the discovery pool for reporting.
    final Set<String> discoverySelectedKeys = <String>{};

    void pickFrom(List<_Ranked> pool, int target, {bool isDiscovery = false}) {
      int remaining = target;
      for (final candidate in pool) {
        if (selected.length >= limit || remaining <= 0) {
          return;
        }
        if (selectedKeys.contains(candidate.key)) {
          continue;
        }
        selected.add(candidate);
        selectedKeys.add(candidate.key);
        if (isDiscovery) {
          discoverySelectedKeys.add(candidate.key);
        }
        remaining -= 1;
      }
    }

    pickFrom(creatorCandidates, creatorTarget);
    pickFrom(discoveryCandidates, discoveryTarget, isDiscovery: true);
    pickFrom(wallhavenCandidates, wallhavenTarget);
    pickFrom(pexelsCandidates, pexelsTarget);

    // Backfill remaining slots from all pools sorted by score.
    if (selected.length < limit) {
      final leftovers = <_Ranked>[
        ...creatorCandidates,
        ...discoveryCandidates,
        ...wallhavenCandidates,
        ...pexelsCandidates,
      ]..sort((a, b) => b.score.compareTo(a.score));
      for (final candidate in leftovers) {
        if (selected.length >= limit) {
          break;
        }
        if (selectedKeys.add(candidate.key)) {
          selected.add(candidate);
        }
      }
    }

    selected.sort((a, b) => b.score.compareTo(a.score));
    final items = selected.map((e) => e.item).toList(growable: false);
    final sourceCounts = <WallpaperSource, int>{
      WallpaperSource.prism: items.where((e) => e.source == WallpaperSource.prism).length,
      WallpaperSource.wallhaven: items.where((e) => e.source == WallpaperSource.wallhaven).length,
      WallpaperSource.pexels: items.where((e) => e.source == WallpaperSource.pexels).length,
    };

    return PersonalizedRankingResult(
      items: items,
      usedKeys: selected.map((e) => e.key).toList(growable: false),
      sourceCounts: sourceCounts,
      discoveryCount: discoverySelectedKeys.length,
    );
  }

  List<_Ranked> _score(
    List<FeedItemEntity> items, {
    required int sourceBase,
    required Set<String> interests,
    required Set<String> blockedKeys,
  }) {
    final ranked = <_Ranked>[];
    for (int index = 0; index < items.length; index += 1) {
      final item = items[index];
      final key = canonicalKey(item);
      if (blockedKeys.contains(key)) {
        continue;
      }

      final searchable = _searchableFields(item);
      int interestHits = 0;
      for (final interest in interests) {
        if (interest.isEmpty) {
          continue;
        }
        final normalized = interest.toLowerCase();
        if (searchable.any((value) => value.contains(normalized))) {
          interestHits += 1;
        }
      }

      final score = sourceBase + (interestHits * 120) + (items.length - index);
      ranked.add(_Ranked(item: item, score: score, key: key));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }

  static String canonicalKey(FeedItemEntity item) {
    final normalizedUrl = _fullUrl(item).trim().toLowerCase();
    if (normalizedUrl.isNotEmpty) {
      return normalizedUrl;
    }
    return '${item.source.wireValue}:${item.id.trim().toLowerCase()}';
  }

  static String _fullUrl(FeedItemEntity item) => item.when(
    prism: (_, wall) => wall.fullUrl,
    wallhaven: (_, wall) => wall.fullUrl,
    pexels: (_, wall) => wall.fullUrl,
  );

  List<String> _searchableFields(FeedItemEntity item) {
    return item.when(
      prism: (_, wall) {
        final fields = <String>[
          wall.core.category ?? '',
          ...(wall.tags ?? const <String>[]),
          ...(wall.collections ?? const <String>[]),
        ];
        return fields.map((e) => e.toLowerCase()).where((e) => e.isNotEmpty).toList(growable: false);
      },
      wallhaven: (_, wall) {
        final fields = <String>[wall.core.category ?? '', ...(wall.tags ?? const <String>[])];
        return fields.map((e) => e.toLowerCase()).where((e) => e.isNotEmpty).toList(growable: false);
      },
      pexels: (_, wall) {
        final fields = <String>[wall.core.category ?? '', wall.photographer ?? ''];
        return fields.map((e) => e.toLowerCase()).where((e) => e.isNotEmpty).toList(growable: false);
      },
    );
  }
}

class _Ranked {
  const _Ranked({required this.item, required this.score, required this.key});

  final FeedItemEntity item;
  final int score;
  final String key;
}
