import 'dart:math';

import 'package:Prism/core/personalization/taste_signals.dart';

/// How far the home feed reaches outside the user's taste.
enum FeedMix {
  familiar(exploreEvery: 8),
  balanced(exploreEvery: 5),
  adventurous(exploreEvery: 3);

  const FeedMix({required this.exploreEvery});

  /// Every n-th feed slot goes to a wallpaper outside the user's taste.
  final int exploreEvery;

  static FeedMix parse(String? raw) => switch (raw?.trim().toLowerCase()) {
    'familiar' || 'creators' => FeedMix.familiar,
    'adventurous' || 'discovery' => FeedMix.adventurous,
    _ => FeedMix.balanced,
  };
}

/// What the user likes, as weights per term (category, tag) and per creator.
/// Built fresh on device from explicit picks, follows and [TasteSignal]s.
class TasteProfile {
  const TasteProfile({required this.terms, required this.creators});

  factory TasteProfile.build({
    required Iterable<String> interests,
    required Iterable<String> following,
    required List<TasteSignal> signals,
    required DateTime now,
  }) {
    final Map<String, double> terms = <String, double>{};
    final Map<String, double> creators = <String, double>{};
    for (final String interest in interests) {
      final String term = interest.trim().toLowerCase();
      if (term.isNotEmpty) {
        terms[term] = (terms[term] ?? 0) + interestWeight;
      }
    }
    for (final String creator in following) {
      final String key = creator.trim().toLowerCase();
      if (key.isNotEmpty) {
        creators[key] = (creators[key] ?? 0) + followWeight;
      }
    }
    for (final TasteSignal signal in signals) {
      final double ageDays = max(0, now.difference(signal.at).inHours / 24);
      final double weight = actionWeights[signal.action]! * pow(0.5, ageDays / halfLifeDays);
      if (signal.terms.isNotEmpty) {
        // Many-tag walls must not outweigh one well-labelled wall.
        final double perTerm = weight / sqrt(signal.terms.length);
        for (final String term in signal.terms) {
          terms[term] = (terms[term] ?? 0) + perTerm;
        }
      }
      final String? creator = signal.creator;
      if (creator != null) {
        creators[creator] = (creators[creator] ?? 0) + weight;
      }
    }
    return TasteProfile(terms: terms, creators: creators);
  }

  static const TasteProfile empty = TasteProfile(terms: <String, double>{}, creators: <String, double>{});

  static const Map<TasteAction, double> actionWeights = <TasteAction, double>{
    TasteAction.open: 1,
    TasteAction.favourite: 3,
    TasteAction.download: 4,
    TasteAction.set: 6,
    TasteAction.lessLikeThis: -8,
  };
  static const double interestWeight = 4;
  static const double followWeight = 6;
  static const double halfLifeDays = 30;

  final Map<String, double> terms;
  final Map<String, double> creators;

  double get _maxTerm => terms.values.fold(1, max);
  double get _maxCreator => creators.values.fold(1, max);

  /// Sum of matched term weights, scaled so the strongest term counts 1.
  /// A taste term matches an item term that contains it ("space" hits "deep space").
  double termAffinity(Iterable<String> itemTerms) {
    if (terms.isEmpty) {
      return 0;
    }
    final double scale = _maxTerm;
    double sum = 0;
    for (final MapEntry<String, double> entry in terms.entries) {
      if (itemTerms.any((term) => term.contains(entry.key))) {
        sum += entry.value / scale;
      }
    }
    return sum.clamp(-2, 2).toDouble();
  }

  double creatorAffinity(String? creator) {
    if (creator == null) {
      return 0;
    }
    final double? weight = creators[creator];
    return weight == null ? 0 : (weight / _maxCreator).clamp(-1, 1).toDouble();
  }

  /// The strongest positive terms, best first.
  List<String> topTerms(int count) {
    final List<MapEntry<String, double>> positive = terms.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return positive.take(count).map((e) => e.key).toList(growable: false);
  }

  /// A term weight in 0..1 relative to the strongest term, for display.
  double strengthOf(String term) => ((terms[term] ?? 0) / _maxTerm).clamp(0, 1).toDouble();
}
