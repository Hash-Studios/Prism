import 'dart:math';

import 'package:Prism/core/personalization/ranking_rules.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';

import 'feed_replay.dart';

/// Users for the wallpaper-screen check: the feed users, plus two whose taste differs inside one category.
const List<ReplayPersona> detailPersonas = <ReplayPersona>[
  ...replayPersonas,
  ReplayPersona(name: 'anime, colorful only', taste: <String>{'anime'}, likedTag: 'colorful'),
  ReplayPersona(
    name: 'city, not one creator',
    taste: <String>{'city'},
    interests: <String>['city'],
    dislikedCreator: 'city-prolific@x.com',
  ),
];

/// What the walls under an open wallpaper look like, over the first [shownCount] of them.
class DetailMetrics {
  DetailMetrics(this.persona);

  final String persona;
  final List<double> _hit = <double>[];
  final List<double> _related = <double>[];
  int hiddenShown = 0;
  int dislikedCreatorShown = 0;
  int pairs = 0;

  /// Share of the walls the user likes (category, liked tag, not a disliked creator).
  double get hitRate => _hit.isEmpty ? 0 : _hit.reduce((a, b) => a + b) / _hit.length;

  /// Mean tag overlap (Jaccard) with the open wall.
  double get related => _related.isEmpty ? 0 : _related.reduce((a, b) => a + b) / _related.length;

  void add(DetailMetrics other) {
    _hit.addAll(other._hit);
    _related.addAll(other._related);
    hiddenShown += other.hiddenShown;
    dislikedCreatorShown += other.dislikedCreatorShown;
    pairs += other.pairs;
  }

  String row(String order) =>
      '| $persona | $order | ${(hitRate * 100).toStringAsFixed(1)}% | ${related.toStringAsFixed(3)} | '
      '$hiddenShown | $dislikedCreatorShown | $pairs |';

  static const String header =
      '| persona | order | liked in next 12 | tag overlap | hidden shown | disliked creator | light/dark pairs |\n'
      '|---|---|---|---|---|---|---|';
}

const int shownCount = 12;
const int _opens = 20;

/// Trains [persona] on the feed with the X 2026 rules, then opens 20 Prism walls (14 in taste, 6 outside) and looks
/// at the first 12 walls under each. The walls come from the same query as the app: the open wall's category, newest
/// first, starting after the open wall, 24 a page. [personal] picks the new order or the query order.
Future<DetailMetrics> replayDetail(ReplayPersona persona, {required bool personal, List<int>? seeds}) async {
  final DetailMetrics total = DetailMetrics(persona.name);
  for (final int seed in seeds ?? replaySeeds) {
    final run = await replayOnce(persona, rulesReplayRanker('x2026', RankingRules.x2026), seed);
    final TasteProfile profile = TasteProfile.build(
      interests: persona.interests,
      following: persona.following,
      signals: run.ctx.signals.read(),
      now: run.ctx.now,
      rules: RankingRules.x2026,
    );
    final List<ReplayWall> prism = run.catalog.where((w) => w.item.source == WallpaperSource.prism).toList();
    final Map<String, ReplayWall> byKey = <String, ReplayWall>{for (final ReplayWall w in prism) w.key: w};
    final Random pick = Random(seed + 7);
    final List<ReplayWall> opens = <ReplayWall>[
      ...(prism.where((w) => persona.taste.contains(w.category)).toList()..shuffle(pick)).take(_opens * 7 ~/ 10),
      ...(prism.where((w) => !persona.taste.contains(w.category)).toList()..shuffle(pick)).take(_opens * 3 ~/ 10),
    ];
    for (final ReplayWall open in opens) {
      final List<ReplayWall> page = _relatedPage(prism, open);
      final List<FeedItemEntity> ordered = personal
          ? rankNextWalls(
              current: open.item,
              items: page.map((w) => w.item).toList(),
              profile: profile,
              hiddenKeys: run.hidden,
            )
          : page.map((w) => w.item).toList();
      final List<ReplayWall> shown = ordered.take(shownCount).map((item) => byKey[item.canonicalKey]!).toList();
      final DetailMetrics one = DetailMetrics(persona.name)
        .._hit.add(shown.where((w) => persona.likes(w) && w.creator != persona.dislikedCreator).length / shown.length)
        .._related.add(shown.map((w) => _overlap(open, w)).reduce((a, b) => a + b) / shown.length)
        ..hiddenShown = shown.where((w) => run.hidden.contains(w.key)).length
        ..dislikedCreatorShown = shown.where((w) => w.creator == persona.dislikedCreator).length
        ..pairs = shown.length - shown.map((w) => w.variantGroup ?? w.key).toSet().length;
      total.add(one);
    }
  }
  return total;
}

/// The app's query: same category, newest first, after the open wall, wrapping to the newest. The bloc drops the open
/// wall's own light/dark partner.
List<ReplayWall> _relatedPage(List<ReplayWall> prism, ReplayWall open) {
  final List<ReplayWall> same =
      prism
          .where((w) => w.category == open.category && w.key != open.key)
          .where((w) => open.variantGroup == null || w.variantGroup != open.variantGroup)
          .toList()
        ..sort((a, b) => b.item.wallpaperCore.createdAt!.compareTo(a.item.wallpaperCore.createdAt!));
  final DateTime anchor = open.item.wallpaperCore.createdAt!;
  final List<ReplayWall> older = same.where((w) => w.item.wallpaperCore.createdAt!.isBefore(anchor)).toList();
  return <ReplayWall>[...older, ...same.where((w) => !older.contains(w))].take(24).toList();
}

double _overlap(ReplayWall a, ReplayWall b) {
  final Set<String> x = a.candidate.terms.toSet();
  final Set<String> y = b.candidate.terms.toSet();
  return x.intersection(y).length / x.union(y).length;
}
