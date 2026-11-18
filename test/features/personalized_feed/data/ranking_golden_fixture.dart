import 'dart:math';

import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';

final DateTime goldenNow = DateTime.utc(2026, 11, 17);
const List<String> _cats = <String>['space', 'city', 'cars', 'nature'];

FeedItemEntity goldenWall(String id, String cat, {String? group, int creator = 0, int ageDays = 3}) =>
    FeedItemEntity.prism(
      id: id,
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: id,
          source: WallpaperSource.prism,
          fullUrl: 'https://g.test/$id.jpg',
          thumbnailUrl: 'https://g.test/$id-t.jpg',
          authorEmail: '$cat-$creator@g.test',
          category: cat,
          createdAt: goldenNow.subtract(Duration(days: ageDays)),
        ),
        tags: <String>[cat],
        variantGroupId: group,
      ),
    );

/// 64 Prism walls in 4 categories (6 light/dark pairs) and 8 Wallhaven walls.
List<RankingCandidate> goldenCandidates() {
  final List<RankingCandidate> out = <RankingCandidate>[];
  for (int c = 0; c < _cats.length; c++) {
    for (int i = 0; i < 16; i++) {
      final String? group = i < 4 ? '${_cats[c]}-g${i ~/ 2}' : null;
      out.add(
        RankingCandidate(
          item: goldenWall('${_cats[c]}-$i', _cats[c], group: group, creator: i % 3, ageDays: (i * 5 + c) % 30),
          pool: CandidatePool.values[(i + c) % 4],
        ),
      );
    }
  }
  for (int i = 0; i < 8; i++) {
    out.add(
      RankingCandidate(
        item: FeedItemEntity.wallhaven(
          id: 'wh$i',
          wallpaper: WallhavenWallpaper(
            core: WallpaperCore(
              id: 'wh$i',
              source: WallpaperSource.wallhaven,
              fullUrl: 'https://g.test/wh$i.jpg',
              thumbnailUrl: 'https://g.test/wh$i-t.jpg',
              authorName: 'wh-$i',
            ),
            tags: <String>[_cats[i % 4]],
          ),
        ),
        pool: CandidatePool.wallhaven,
      ),
    );
  }
  return out;
}

List<TasteSignal> goldenSignals() => <TasteSignal>[
  for (int i = 0; i < 5; i++)
    TasteSignal(
      action: TasteAction.favourite,
      at: goldenNow.subtract(Duration(days: i)),
      terms: const <String>['city', 'hd'],
      creator: 'city-$i@g.test',
    ),
  TasteSignal(
    action: TasteAction.lessLikeThis,
    at: goldenNow.subtract(const Duration(days: 2)),
    terms: const <String>['cars', 'hd'],
  ),
  TasteSignal(
    action: TasteAction.open,
    at: goldenNow.subtract(const Duration(days: 40)),
    terms: const <String>['ocean'],
  ),
  TasteSignal(action: TasteAction.set, at: goldenNow, terms: const <String>['space'], creator: 'space-1@g.test'),
];

/// Ranked ids for three pages and two mixes, as one string.
String goldenOrder(
  TasteProfile Function(List<TasteSignal> signals) profileOf,
  List<String> Function({
    required List<RankingCandidate> candidates,
    required TasteProfile profile,
    required Map<String, int> recentShows,
    required Set<String> excludedKeys,
    required Random random,
  })
  rank,
  List<TasteSignal> signals,
) {
  final List<RankingCandidate> candidates = goldenCandidates();
  final TasteProfile profile = profileOf(signals);
  final Map<String, int> shows = <String, int>{
    'https://g.test/city-0.jpg': 2,
    'https://g.test/space-4.jpg': 1,
    'https://g.test/nature-5.jpg': 99,
  };
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (int page = 0; page < 3; page++) {
    final List<String> keys = rank(
      candidates: candidates,
      profile: profile,
      recentShows: shows,
      excludedKeys: seen,
      random: Random(page + 11),
    );
    seen.addAll(keys);
    out.add(keys.map((k) => k.split('/').last.replaceAll('.jpg', '')).join(','));
  }
  return out.join('\n');
}
