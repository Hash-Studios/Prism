import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';

const int tasteQuizRounds = 6;

/// Wild-card rounds sit in the middle, so the quiz opens and closes on the user's own categories.
const List<int> _wildRoundsAt = <int>[2, 4];
const int _maxWildRounds = 2;

const Map<String, QuizTone> _toneWords = <String, QuizTone>{
  'dark': QuizTone.dark,
  'black': QuizTone.dark,
  'night': QuizTone.dark,
  'amoled': QuizTone.dark,
  'moody': QuizTone.dark,
  'light': QuizTone.light,
  'white': QuizTone.light,
  'bright': QuizTone.light,
  'pastel': QuizTone.light,
  'sunny': QuizTone.light,
};

const Map<String, QuizDensity> _densityWords = <String, QuizDensity>{
  'minimal': QuizDensity.minimal,
  'minimalism': QuizDensity.minimal,
  'minimalist': QuizDensity.minimal,
  'simple': QuizDensity.minimal,
  'clean': QuizDensity.minimal,
  'flat': QuizDensity.minimal,
  'gradient': QuizDensity.minimal,
  'solid': QuizDensity.minimal,
  'plain': QuizDensity.minimal,
  'city': QuizDensity.busy,
  'cityscape': QuizDensity.busy,
  'pattern': QuizDensity.busy,
  'detailed': QuizDensity.busy,
  'texture': QuizDensity.busy,
  'collage': QuizDensity.busy,
  'crowd': QuizDensity.busy,
  'graffiti': QuizDensity.busy,
  'street': QuizDensity.busy,
  'floral': QuizDensity.busy,
  'forest': QuizDensity.busy,
};

/// What the dominant palette colour says about a wall. A mid colour says nothing about tone.
const Map<String, (QuizTone?, QuizMood)> _paletteTraits = <String, (QuizTone?, QuizMood)>{
  'red': (null, QuizMood.warm),
  'orange': (null, QuizMood.warm),
  'yellow': (QuizTone.light, QuizMood.warm),
  'pink': (null, QuizMood.warm),
  'brown': (QuizTone.dark, QuizMood.warm),
  'green': (null, QuizMood.cool),
  'teal': (QuizTone.light, QuizMood.cool),
  'blue': (null, QuizMood.cool),
  'purple': (QuizTone.dark, QuizMood.cool),
  'black': (QuizTone.dark, QuizMood.mono),
  'grey': (null, QuizMood.mono),
  'white': (QuizTone.light, QuizMood.mono),
};

/// Reads a wall's traits from its tags first, then from its most dominant colour.
QuizWall quizWallOf(FeedItemEntity item, {required String category, required bool wildCard}) {
  final (List<String> tags, List<String> collections, List<String> colors) = item.when(
    prism: (_, wall) => (wall.tags ?? const <String>[], wall.collections ?? const <String>[], wall.colors ?? const []),
    wallhaven: (_, wall) => (wall.tags ?? const <String>[], const <String>[], wall.colors ?? const <String>[]),
    pexels: (_, _) => (const <String>[], const <String>[], const <String>[]),
  );
  final List<String> terms = tasteTermsOf(
    item.wallpaperCore,
    tags: <String>[...tags, category],
    collections: collections,
  );
  final (QuizTone?, QuizMood)? palette = colors.isEmpty ? null : _paletteTraits[_paletteId(colors.first)];
  return QuizWall(
    item: item,
    category: category,
    wildCard: wildCard,
    terms: terms,
    tone: _wordTrait(terms, _toneWords) ?? palette?.$1,
    density: _wordTrait(terms, _densityWords) ?? (colors.length == 1 ? QuizDensity.minimal : null),
    mood: palette?.$2,
  );
}

T? _wordTrait<T>(List<String> terms, Map<String, T> words) {
  for (final String term in terms) {
    for (final String word in term.split(' ')) {
      final T? trait = words[word];
      if (trait != null) return trait;
    }
  }
  return null;
}

/// Prism stores palette ids. Wallhaven stores hex such as `#000000`.
String? _paletteId(String color) {
  final String value = color.trim().toLowerCase();
  if (paletteColorById(value) != null) return value;
  final int? rgb = int.tryParse(value.replaceFirst('#', ''), radix: 16);
  return rgb == null ? null : nearestPaletteColor(Color(0xFF000000 | rgb)).id;
}

/// How far apart two walls are. Tone counts most, because light against dark is the easiest choice to read.
int quizContrast(QuizWall a, QuizWall b) {
  bool differ<T>(T? x, T? y) => x != null && y != null && x != y;
  return (differ(a.tone, b.tone) ? 3 : 0) +
      (differ(a.density, b.density) ? 2 : 0) +
      (differ(a.mood, b.mood) ? 2 : 0) +
      (a.category != b.category ? 1 : 0);
}

int _knownTraits(QuizWall wall) => <Object?>[wall.tone, wall.density, wall.mood].nonNulls.length;

/// Chooses all [tasteQuizRounds] pairs at once, or returns null when there are too few walls.
///
/// Up to two rounds are wild cards from categories the user did not pick. Each round starts from the remaining wall
/// with the most known traits and pairs it with the wall that contrasts with it most. No wall shows twice.
TasteQuizPlan? planTasteQuiz(List<QuizWall> walls, Random random) {
  final Set<String> seen = <String>{};
  final List<QuizWall> unique = walls.where((wall) => seen.add(wall.key)).toList()..shuffle(random);
  final List<QuizWall> interest = unique.where((wall) => !wall.wildCard).toList();
  final List<QuizWall> wild = unique.where((wall) => wall.wildCard).toList();
  final int wildRounds = min(_maxWildRounds, wild.length ~/ 2);
  if (interest.length < (tasteQuizRounds - wildRounds) * 2) return null;
  final Set<int> wildAt = _wildRoundsAt.take(wildRounds).toSet();

  final List<QuizRound> rounds = <QuizRound>[];
  for (int i = 0; i < tasteQuizRounds; i++) {
    final List<QuizWall> source = wildAt.contains(i) ? wild : interest;
    final QuizWall anchor = source.reduce((best, wall) => _knownTraits(wall) > _knownTraits(best) ? wall : best);
    source.remove(anchor);
    final QuizWall partner = source.reduce(
      (best, wall) => quizContrast(anchor, wall) > quizContrast(anchor, best) ? wall : best,
    );
    source.remove(partner);
    rounds.add(random.nextBool() ? QuizRound(left: anchor, right: partner) : QuizRound(left: partner, right: anchor));
  }
  return TasteQuizPlan(rounds: rounds, pool: <QuizWall>[...interest, ...wild]);
}

/// What the picks say, for the one line on "Tuning your feed". Every part is null unless the picks clearly agree.
class TasteSummary {
  const TasteSummary({this.tone, this.density, this.tag});

  final QuizTone? tone;
  final QuizDensity? density;

  /// A tag from the picked walls, as it is stored.
  final String? tag;

  bool get isEmpty => tone == null && density == null && tag == null;
}

const int _maxSummaryTagLength = 16;

/// How bright and how detailed a wall looks, measured from a small copy of its pixels.
class WallLook {
  const WallLook({required this.luma, required this.edges});

  /// Mean brightness, 0 (black) to 1 (white).
  final double luma;

  /// Mean brightness change between neighbouring pixels, 0 (flat) to 1.
  final double edges;
}

/// Measures [rgba] (straight RGBA, 4 bytes a pixel). Fully transparent pixels are skipped.
WallLook wallLookOf(Uint8List rgba, int width, int height) {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) return const WallLook(luma: 0.5, edges: 0.06);
  double luma(int x, int y) {
    final int i = (y * width + x) * 4;
    return (0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2]) / 255;
  }

  bool opaque(int x, int y) => rgba[(y * width + x) * 4 + 3] != 0;
  double sum = 0;
  int count = 0;
  double edgeSum = 0;
  int edgeCount = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (!opaque(x, y)) continue;
      final double here = luma(x, y);
      sum += here;
      count++;
      if (x + 1 < width && opaque(x + 1, y)) {
        edgeSum += (here - luma(x + 1, y)).abs();
        edgeCount++;
      }
      if (y + 1 < height && opaque(x, y + 1)) {
        edgeSum += (here - luma(x, y + 1)).abs();
        edgeCount++;
      }
    }
  }
  return WallLook(luma: count == 0 ? 0.5 : sum / count, edges: edgeCount == 0 ? 0 : edgeSum / edgeCount);
}

// ponytail: these cut-offs are not calibrated on real walls; tune them with ~20 labelled walls.
const double _darkBelow = 0.30;
const double _lightAbove = 0.62;
const double _minimalBelow = 0.035;
const double _busyAbove = 0.09;

QuizTone? toneOfLook(WallLook? look) {
  if (look == null) return null;
  if (look.luma < _darkBelow) return QuizTone.dark;
  return look.luma > _lightAbove ? QuizTone.light : null;
}

QuizDensity? densityOfLook(WallLook? look) {
  if (look == null) return null;
  if (look.edges < _minimalBelow) return QuizDensity.minimal;
  return look.edges > _busyAbove ? QuizDensity.busy : null;
}

/// [looks] is keyed by [QuizWall.key]. Measured brightness beats a tag or colour guess.
/// An explicit density tag beats the small-copy estimate.
TasteSummary summarizeTaste(List<QuizPick> picks, {Map<String, WallLook> looks = const <String, WallLook>{}}) {
  final int majority = max(2, (picks.length * 2 / 3).ceil());
  T? agreed<T extends Object>(Iterable<T?> traits) {
    final Map<T, int> counts = <T, int>{};
    for (final T trait in traits.nonNulls) {
      counts[trait] = (counts[trait] ?? 0) + 1;
    }
    for (final MapEntry<T, int> entry in counts.entries) {
      if (entry.value >= majority) return entry.key;
    }
    return null;
  }

  return TasteSummary(
    tone: agreed(picks.map((pick) => toneOfLook(looks[pick.picked.key]) ?? pick.picked.tone)),
    density: agreed(picks.map((pick) => pick.picked.density ?? densityOfLook(looks[pick.picked.key]))),
    tag: _summaryTag(picks),
  );
}

/// The tag most picked walls share, when it shows up on at least two picks and more picks than passes.
/// Tone and density words are left out, since the line already says those.
String? _summaryTag(List<QuizPick> picks) {
  final Map<String, int> picked = <String, int>{};
  final Map<String, int> passed = <String, int>{};
  final Set<String> categories = <String>{};
  for (final QuizPick pick in picks) {
    categories.add(pick.picked.category.toLowerCase());
    for (final String term in pick.picked.terms) {
      picked[term] = (picked[term] ?? 0) + 1;
    }
    for (final String term in pick.passed.terms) {
      passed[term] = (passed[term] ?? 0) + 1;
    }
  }
  bool describable(String term) =>
      term.length <= _maxSummaryTagLength &&
      !term.contains(RegExp('[0-9]')) &&
      !term.split(' ').any((word) => _toneWords.containsKey(word) || _densityWords.containsKey(word));
  final List<MapEntry<String, int>> candidates =
      picked.entries
          .where((entry) => entry.value >= 2 && entry.value > (passed[entry.key] ?? 0) && describable(entry.key))
          .toList()
        ..sort((a, b) {
          final int byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          // A tag the user did not already pick as a category says more.
          final int byNovelty = (categories.contains(a.key) ? 1 : 0) - (categories.contains(b.key) ? 1 : 0);
          return byNovelty != 0 ? byNovelty : a.key.compareTo(b.key);
        });
  return candidates.firstOrNull?.key;
}
