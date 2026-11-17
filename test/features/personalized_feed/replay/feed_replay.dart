import 'dart:math';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/ranking_rules.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';

import '../../../support/in_memory_local_store.dart';

/// Offline replay of the For you ranker. Seeded fake users with a known taste browse a fixed, seeded catalog for
/// several sessions. Their actions go through the real [TasteSignalStore] and [FeedImpressionStore], so the caps,
/// decay and hides behave as in the app.

const Map<String, List<String>> replayCategories = <String, List<String>>{
  'amoled': <String>['amoled', 'black', 'oled'],
  'anime': <String>['anime', 'manga', 'character'],
  'nature': <String>['nature', 'forest', 'mountains'],
  'cars': <String>['cars', 'supercar', 'road'],
  'space': <String>['space', 'galaxy', 'stars'],
  'minimal': <String>['minimal', 'clean', 'simple'],
  'abstract': <String>['abstract', 'shapes', 'fluid'],
  'city': <String>['city', 'skyline', 'buildings'],
  'neon': <String>['neon', 'cyberpunk', 'glow'],
  'ocean': <String>['ocean', 'sea', 'waves'],
};

const List<String> _sharedTags = <String>['4k', 'hd', 'colorful', 'portrait'];

class ReplayWall {
  ReplayWall({required this.item, required this.pool, required this.category, this.variantGroup});

  final FeedItemEntity item;
  final CandidatePool pool;
  final String category;
  final String? variantGroup;

  String get key => item.canonicalKey;
  String? get creator => tasteCreatorOf(item.wallpaperCore);
  RankingCandidate get candidate => asCandidate(pool);

  /// The repository tags an external wall with the interest whose search found it.
  RankingCandidate asCandidate(CandidatePool pool) => RankingCandidate(
    item: item,
    pool: pool,
    extraTerms: item.source == WallpaperSource.prism ? const <String>[] : <String>[category],
  );
}

/// 1,030 Prism walls (100 per category, 3 light/dark pairs each), 80 Wallhaven and 60 Pexels walls.
/// Each category has one prolific creator with about 40% of its walls.
List<ReplayWall> buildReplayCatalog(DateTime now) {
  final Random random = Random(42);
  final List<ReplayWall> out = <ReplayWall>[];
  DateTime age() => now.subtract(Duration(hours: random.nextInt(60 * 24)));
  List<String> tagsFor(String category) {
    final List<String> own = <String>[...replayCategories[category]!]..shuffle(random);
    return <String>[...own.take(2), _sharedTags[random.nextInt(_sharedTags.length)]];
  }

  for (final String category in replayCategories.keys) {
    for (int i = 0; i < 100; i++) {
      final double roll = random.nextDouble();
      final String creator = roll < 0.4
          ? '$category-prolific@x.com'
          : roll < 0.9
          ? '$category-${random.nextInt(4)}@x.com'
          : 'generalist-${random.nextInt(10)}@x.com';
      final List<String> tags = tagsFor(category);
      final DateTime createdAt = age();
      final bool paired = i < 3;
      final CandidatePool pool = random.nextBool() ? CandidatePool.gems : CandidatePool.fresh;
      for (int v = 0; v < (paired ? 2 : 1); v++) {
        final String id = paired ? '$category-p$i-$v' : '$category-$i';
        out.add(
          ReplayWall(
            item: FeedItemEntity.prism(
              id: id,
              wallpaper: PrismWallpaper(
                core: WallpaperCore(
                  id: id,
                  source: WallpaperSource.prism,
                  fullUrl: 'https://walls.test/$id.jpg',
                  thumbnailUrl: 'https://walls.test/$id-t.jpg',
                  authorEmail: creator,
                  category: category[0].toUpperCase() + category.substring(1),
                  createdAt: createdAt,
                ),
                tags: tags,
                variantGroupId: paired ? 'group-$category-$i' : null,
                variantIndex: paired ? v : null,
              ),
            ),
            pool: pool,
            category: category,
            variantGroup: paired ? 'group-$category-$i' : null,
          ),
        );
      }
    }
    for (int i = 0; i < 8; i++) {
      final String id = 'wh-$category-$i';
      out.add(
        ReplayWall(
          item: FeedItemEntity.wallhaven(
            id: id,
            wallpaper: WallhavenWallpaper(
              core: WallpaperCore(
                id: id,
                source: WallpaperSource.wallhaven,
                fullUrl: 'https://wallhaven.test/$id.jpg',
                thumbnailUrl: 'https://wallhaven.test/$id-t.jpg',
                authorName: 'wh-user-${random.nextInt(30)}',
              ),
              tags: tagsFor(category),
            ),
          ),
          pool: CandidatePool.wallhaven,
          category: category,
        ),
      );
    }
    for (int i = 0; i < 6; i++) {
      final String id = 'px-$category-$i';
      out.add(
        ReplayWall(
          item: FeedItemEntity.pexels(
            id: id,
            wallpaper: PexelsWallpaper(
              core: WallpaperCore(
                id: id,
                source: WallpaperSource.pexels,
                fullUrl: 'https://pexels.test/$id.jpg',
                thumbnailUrl: 'https://pexels.test/$id-t.jpg',
                authorName: 'photographer-${random.nextInt(30)}',
              ),
            ),
          ),
          pool: CandidatePool.pexels,
          category: category,
        ),
      );
    }
  }
  return out;
}

/// A fake user. [taste] is the truth the metrics check. [interests] and [startSignals] are what the app knows on day 0.
class ReplayPersona {
  const ReplayPersona({
    required this.name,
    required this.taste,
    this.disliked = const <String>{},
    this.interests = const <String>[],
    this.following = const <String>[],
    this.history = const <String, int>{},
    this.lessLikeAtStart = const <String, int>{},
    this.openRate = 0.45,
    this.gridSaveRate = 0,
  });

  final String name;
  final Set<String> taste;
  final Set<String> disliked;
  final List<String> interests;
  final List<String> following;

  /// Category to the number of past favourites in it, recorded before day 0.
  final Map<String, int> history;

  /// Category to the number of "Show less like this" taps before day 0.
  final Map<String, int> lessLikeAtStart;

  /// Chance to open a wall in [taste].
  final double openRate;

  /// Chance to save a wall in [taste] to a folder from the grid, without opening it.
  final double gridSaveRate;
}

const List<ReplayPersona> replayPersonas = <ReplayPersona>[
  ReplayPersona(name: 'amoled only', taste: <String>{'amoled'}, interests: <String>['amoled']),
  ReplayPersona(
    name: 'anime + nature',
    taste: <String>{'anime', 'nature'},
    history: <String, int>{'anime': 3, 'nature': 3},
  ),
  ReplayPersona(name: 'new user', taste: <String>{'space'}),
  ReplayPersona(
    name: 'less like cars',
    taste: <String>{'city', 'neon'},
    disliked: <String>{'cars'},
    interests: <String>['city', 'neon'],
    history: <String, int>{'city': 40, 'neon': 40},
    lessLikeAtStart: <String, int>{'cars': 2},
  ),
  ReplayPersona(name: 'stale interest', taste: <String>{'space'}, interests: <String>['cars', 'space']),
  ReplayPersona(name: 'grid saver', taste: <String>{'ocean'}, openRate: 0.1, gridSaveRate: 0.35),
  ReplayPersona(
    name: 'broad taste',
    taste: <String>{'nature', 'ocean', 'space', 'minimal'},
    interests: <String>['nature', 'ocean'],
    following: <String>['nature-prolific@x.com'],
  ),
];

/// What one ranker run needs. The harness builds the profile with [buildProfile] and ranks with [rank], so a variant
/// can change either one.
class ReplayRanker {
  const ReplayRanker({required this.name, required this.buildProfile, required this.rank, this.afterRank});

  final String name;
  final TasteProfile Function({
    required Iterable<String> interests,
    required Iterable<String> following,
    required List<TasteSignal> signals,
    required DateTime now,
  })
  buildProfile;
  final PersonalizedRankingResult Function({
    required List<RankingCandidate> candidates,
    required TasteProfile profile,
    required Map<String, int> recentShows,
    required Set<String> excludedKeys,
    required FeedMix mix,
    required Random random,
    required DateTime now,
  })
  rank;

  /// Runs after each ranking, like the repository's side effects.
  final Future<void> Function(
    ReplayContext context,
    List<RankingCandidate> candidates,
    Map<String, int> recentShows,
    Set<String> excludedKeys,
  )?
  afterRank;
}

class ReplayContext {
  ReplayContext(this.signals, this.impressions, this.now);

  final TasteSignalStore signals;
  final FeedImpressionStore impressions;
  DateTime now;
}

final ReplayRanker legacyReplayRanker = ReplayRanker(
  name: 'master',
  buildProfile: TasteProfile.build,
  rank: const PersonalizedRankingService().rank,
);

/// The shipped ranker with [rules], wired the way the repository wires it.
ReplayRanker rulesReplayRanker(String name, RankingRules rules) => ReplayRanker(
  name: name,
  buildProfile: ({required interests, required following, required signals, required now}) =>
      TasteProfile.build(interests: interests, following: following, signals: signals, now: now, rules: rules),
  rank:
      ({
        required candidates,
        required profile,
        required recentShows,
        required excludedKeys,
        required mix,
        required random,
        required now,
      }) => const PersonalizedRankingService().rank(
        candidates: candidates,
        profile: profile,
        recentShows: recentShows,
        excludedKeys: excludedKeys,
        mix: mix,
        random: random,
        now: now,
        rules: rules,
      ),
  afterRank: rules.scrolledPast
      ? (ctx, candidates, recentShows, excludedKeys) => ctx.signals.recordAll(
          scrolledPastSignals(
            candidates: candidates,
            recentShows: recentShows,
            excludedKeys: excludedKeys,
            signaledKeys: ctx.signals.signaledKeys(),
            now: ctx.now,
          ),
        )
      : null,
);

class ReplayMetrics {
  ReplayMetrics(this.persona);

  final String persona;
  final List<double> _hit = <double>[];
  final List<double> _firstHit = <double>[];
  final List<double> _maxCreator = <double>[];
  final List<double> _maxCategory = <double>[];
  final List<double> _repeat = <double>[];
  int dislikedShown = 0;
  int shownAfterDislike = 0;
  int hiddenBack = 0;
  int variantDupes = 0;
  int pages = 0;

  void addPage(List<ReplayWall> page, Set<String> taste, {required bool first, required bool firstSession}) {
    if (page.isEmpty) return;
    pages++;
    final double hit = page.where((w) => taste.contains(w.category)).length / page.length;
    if (first) {
      _hit.add(hit);
      if (firstSession) _firstHit.add(hit);
    }
    final Map<String, int> creators = <String, int>{};
    final Map<String, int> categories = <String, int>{};
    final Set<String> groups = <String>{};
    for (final ReplayWall w in page) {
      if (w.creator != null) creators[w.creator!] = (creators[w.creator!] ?? 0) + 1;
      categories[w.category] = (categories[w.category] ?? 0) + 1;
      if (w.variantGroup != null && !groups.add(w.variantGroup!)) variantDupes++;
    }
    _maxCreator.add(creators.values.fold(0, max).toDouble());
    _maxCategory.add(categories.values.fold(0, max) / page.length);
  }

  void addRepeat(double share) => _repeat.add(share);

  static double _mean(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  /// Share of the top 24 in the user's true taste, over all sessions.
  double get hitRate => _mean(_hit);

  /// Share of the top 24 in the true taste on the first session.
  double get coldStartHit => _mean(_firstHit);

  /// Most walls from one creator in a page of 24.
  double get maxPerCreator => _mean(_maxCreator);

  /// Biggest share of one category in a page.
  double get maxCategoryShare => _mean(_maxCategory);

  /// Share of page 1 that the previous session already showed.
  double get repeatRate => _mean(_repeat);

  /// Share of walls from a disliked category after the user said so.
  double get dislikedRate => shownAfterDislike == 0 ? 0 : dislikedShown / shownAfterDislike;

  ReplayMetrics merge(ReplayMetrics other) => ReplayMetrics(persona)
    .._hit.addAll(<double>[..._hit, ...other._hit])
    .._firstHit.addAll(<double>[..._firstHit, ...other._firstHit])
    .._maxCreator.addAll(<double>[..._maxCreator, ...other._maxCreator])
    .._maxCategory.addAll(<double>[..._maxCategory, ...other._maxCategory])
    .._repeat.addAll(<double>[..._repeat, ...other._repeat])
    ..dislikedShown = dislikedShown + other.dislikedShown
    ..shownAfterDislike = shownAfterDislike + other.shownAfterDislike
    ..hiddenBack = hiddenBack + other.hiddenBack
    ..variantDupes = variantDupes + other.variantDupes
    ..pages = pages + other.pages;

  String row(String ranker) =>
      '| $persona | $ranker | ${_pct(hitRate)} | ${_pct(coldStartHit)} | ${maxPerCreator.toStringAsFixed(2)} | '
      '${_pct(maxCategoryShare)} | ${_pct(repeatRate)} | ${_pct(dislikedRate)} | $hiddenBack | $variantDupes |';

  static const String header =
      '| persona | ranker | hit@24 | cold hit | max/creator | max category | repeat | disliked | hidden back | '
      'variant dupes |\n|---|---|---|---|---|---|---|---|---|---|';

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}

const int replaySessions = 8;
const int replayPagesPerSession = 2;
final List<int> replaySeeds = List<int>.generate(20, (i) => i + 1);

/// Runs [persona] for every seed and merges the metrics.
Future<ReplayMetrics> replay(ReplayPersona persona, ReplayRanker ranker, {List<int>? seeds}) async {
  ReplayMetrics? total;
  for (final int seed in seeds ?? replaySeeds) {
    final ReplayMetrics run = await _replayOnce(persona, ranker, seed);
    total = total == null ? run : total.merge(run);
  }
  return total!;
}

Future<ReplayMetrics> _replayOnce(ReplayPersona persona, ReplayRanker ranker, int seed) async {
  TasteSignal.clearRememberedFeedTerms();
  final DateTime start = DateTime.utc(2026, 11);
  final List<ReplayWall> catalog = buildReplayCatalog(start);
  final Map<String, ReplayWall> byKey = <String, ReplayWall>{for (final ReplayWall w in catalog) w.key: w};
  final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
  final ReplayContext ctx = ReplayContext(TasteSignalStore(settings), FeedImpressionStore(settings), start);
  final ReplayMetrics metrics = ReplayMetrics(persona.name);
  final Random behaviour = Random(seed * 7919 + persona.name.codeUnits.fold(0, (a, b) => a * 31 + b) % 100000);

  TasteSignal signalFor(TasteAction action, ReplayWall wall, DateTime at) {
    rememberFeedTerms(wall.key, wall.candidate.terms);
    return wall.item.when(
      prism: (_, w) => TasteSignal.forWallpaper(action, w.core, tags: w.tags, collections: w.collections, at: at),
      wallhaven: (_, w) => TasteSignal.forWallpaper(action, w.core, tags: w.tags, at: at),
      pexels: (_, w) => TasteSignal.forWallpaper(action, w.core, at: at),
    );
  }

  final Random setup = Random(seed);
  final List<TasteSignal> past = <TasteSignal>[];
  final DateTime pastAt = start.subtract(const Duration(days: 3));
  persona.history.forEach((category, count) {
    final List<ReplayWall> walls = catalog.where((w) => w.category == category).toList()..shuffle(setup);
    past.addAll(walls.take(count).map((w) => signalFor(TasteAction.favourite, w, pastAt)));
  });
  for (final MapEntry<String, int> entry in persona.lessLikeAtStart.entries) {
    final List<ReplayWall> walls = catalog.where((w) => w.category == entry.key).toList()..shuffle(setup);
    for (final ReplayWall w in walls.take(entry.value)) {
      past.add(signalFor(TasteAction.lessLikeThis, w, pastAt));
      await ctx.impressions.hide(w.key, pastAt);
    }
  }
  await ctx.signals.recordAll(past);
  final Set<String> hidden = <String>{
    for (final MapEntry<String, int> e in ctx.impressions.recentShows(start).entries)
      if (e.value >= FeedImpressionStore.hiddenShows) e.key,
  };
  bool dislikeSaid = persona.lessLikeAtStart.isNotEmpty;
  Set<String> previousFirstPage = <String>{};

  for (int session = 0; session < replaySessions; session++) {
    final DateTime now = start.add(Duration(days: session));
    ctx.now = now;
    final Random pools = Random(seed * 1000 + session);
    final TasteProfile profile = ranker.buildProfile(
      interests: persona.interests,
      following: persona.following,
      signals: ctx.signals.read(),
      now: now,
    );
    final List<RankingCandidate> candidates = _candidates(catalog, persona, profile, pools, now);
    final List<String> seen = <String>[];
    for (int page = 0; page < replayPagesPerSession; page++) {
      final Map<String, int> recentShows = ctx.impressions.recentShows(now);
      final PersonalizedRankingResult result = ranker.rank(
        candidates: candidates,
        profile: page == 0
            ? profile
            : ranker.buildProfile(
                interests: persona.interests,
                following: persona.following,
                signals: ctx.signals.read(),
                now: now,
              ),
        recentShows: recentShows,
        excludedKeys: seen.toSet(),
        mix: FeedMix.balanced,
        random: Random(seed * 100000 + session * 10 + page),
        now: now,
      );
      await ranker.afterRank?.call(ctx, candidates, recentShows, seen.toSet());
      final List<ReplayWall> shown = result.usedKeys.map((k) => byKey[k]!).toList();
      seen.addAll(result.usedKeys);
      metrics.addPage(shown, persona.taste, first: page == 0, firstSession: session == 0);
      if (page == 0) {
        if (session > 0) {
          metrics.addRepeat(shown.where((w) => previousFirstPage.contains(w.key)).length / max(1, shown.length));
        }
        previousFirstPage = shown.map((w) => w.key).toSet();
      }
      final List<TasteSignal> actions = <TasteSignal>[];
      for (final ReplayWall wall in shown) {
        if (hidden.contains(wall.key)) metrics.hiddenBack++;
        if (dislikeSaid) {
          metrics.shownAfterDislike++;
          if (persona.disliked.contains(wall.category)) metrics.dislikedShown++;
        }
        if (persona.disliked.contains(wall.category)) {
          if (behaviour.nextDouble() < 0.6) {
            actions.add(signalFor(TasteAction.lessLikeThis, wall, now));
            await ctx.impressions.hide(wall.key, now);
            hidden.add(wall.key);
            dislikeSaid = true;
          }
          continue;
        }
        final bool liked = persona.taste.contains(wall.category);
        if (liked && behaviour.nextDouble() < persona.gridSaveRate) {
          actions.add(signalFor(TasteAction.folderAdd, wall, now));
        }
        if (behaviour.nextDouble() >= (liked ? persona.openRate : 0.04)) continue;
        actions.add(signalFor(TasteAction.open, wall, now));
        if (!liked) continue;
        if (behaviour.nextDouble() < 0.35) actions.add(signalFor(TasteAction.favourite, wall, now));
        if (behaviour.nextDouble() < 0.2) actions.add(signalFor(TasteAction.download, wall, now));
        if (behaviour.nextDouble() < 0.08) actions.add(signalFor(TasteAction.set, wall, now));
        if (behaviour.nextDouble() < 0.05) actions.add(signalFor(TasteAction.share, wall, now));
        if (behaviour.nextDouble() < 0.1) actions.add(signalFor(TasteAction.folderAdd, wall, now));
      }
      await ctx.signals.recordAll(actions);
      await ctx.impressions.recordShown(result.usedKeys, now);
    }
  }
  return metrics;
}

/// The pools of one feed load, shaped like the repository's: fresh (newest 40), gems (random 30), taste (12 from each
/// of the top 2 taste categories), following, Wallhaven (3 interest queries) and Pexels (2 interest queries).
List<RankingCandidate> _candidates(
  List<ReplayWall> catalog,
  ReplayPersona persona,
  TasteProfile profile,
  Random random,
  DateTime now,
) {
  final List<ReplayWall> prism = catalog.where((w) => w.item.source == WallpaperSource.prism).toList();
  List<ReplayWall> sample(Iterable<ReplayWall> from, int n) => (from.toList()..shuffle(random)).take(n).toList();
  final List<ReplayWall> fresh = prism.where((w) => w.item.wallpaperCore.createdAt!.isBefore(now)).toList()
    ..sort((a, b) => b.item.wallpaperCore.createdAt!.compareTo(a.item.wallpaperCore.createdAt!));
  final List<String> tasteCategories = <String>{
    for (final String term in profile.topTerms(6))
      ?replayCategories.keys.where((c) => term.contains(c) || c.contains(term)).firstOrNull,
  }.toList()..shuffle(random);
  final List<String> queries = persona.interests.isEmpty
      ? (replayCategories.keys.toList()..shuffle(random))
      : (persona.interests.toList()..shuffle(random));
  RankingCandidate cand(ReplayWall w, CandidatePool pool) => w.asCandidate(pool);
  return <RankingCandidate>[
    for (final ReplayWall w in fresh.take(40)) cand(w, CandidatePool.fresh),
    for (final ReplayWall w in sample(prism, 30)) cand(w, CandidatePool.gems),
    for (final String c in tasteCategories.take(2))
      for (final ReplayWall w in sample(prism.where((w) => w.category == c), 12)) cand(w, CandidatePool.taste),
    for (final ReplayWall w in sample(prism.where((w) => persona.following.contains(w.creator)), 30))
      cand(w, CandidatePool.following),
    for (final String q in queries.take(3))
      for (final ReplayWall w in catalog.where((w) => w.pool == CandidatePool.wallhaven && w.category == q))
        cand(w, CandidatePool.wallhaven),
    for (final String q in queries.take(2))
      for (final ReplayWall w in catalog.where((w) => w.pool == CandidatePool.pexels && w.category == q))
        cand(w, CandidatePool.pexels),
  ];
}
