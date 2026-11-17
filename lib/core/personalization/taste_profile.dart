import 'dart:math';

import 'package:Prism/core/personalization/ranking_rules.dart';
import 'package:Prism/core/personalization/taste_signals.dart';

/// What the user likes, as weights per term (category, tag) and per creator.
/// Built fresh on device from explicit picks, follows and [TasteSignal]s.
class TasteProfile {
  const TasteProfile({required this.terms, required this.creators, this.hardNegatives = false});

  factory TasteProfile.build({
    required Iterable<String> interests,
    required Iterable<String> following,
    required List<TasteSignal> signals,
    required DateTime now,
    RankingRules rules = RankingRules.legacy,
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
      final double? actionWeight = _weightOf(signal.action, rules);
      if (actionWeight == null) {
        continue;
      }
      final double ageDays = max(0, now.difference(signal.at).inHours / 24);
      final double weight = actionWeight * pow(0.5, ageDays / halfLifeDays);
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
    return TasteProfile(terms: terms, creators: creators, hardNegatives: rules.hardNegatives);
  }

  static double? _weightOf(TasteAction action, RankingRules rules) => switch (action) {
    TasteAction.share || TasteAction.folderAdd => rules.newActions ? newActionWeights[action] : null,
    TasteAction.scrolledPast => rules.scrolledPast ? newActionWeights[action] : null,
    _ => actionWeights[action],
  };

  static const TasteProfile empty = TasteProfile(terms: <String, double>{}, creators: <String, double>{});

  static const Map<TasteAction, double> actionWeights = <TasteAction, double>{
    TasteAction.open: 1,
    TasteAction.favourite: 3,
    TasteAction.download: 4,
    TasteAction.set: 6,
    TasteAction.lessLikeThis: -8,
    // Losing one pair is a hint, not a dislike.
    TasteAction.passedOver: -0.5,
  };

  /// Actions that count only under [RankingRules]. A share is a strong vote, as in X's weights. A folder add is a
  /// favourite with intent. A wall shown twice without a tap is a weak no.
  static const Map<TasteAction, double> newActionWeights = <TasteAction, double>{
    TasteAction.share: 5,
    TasteAction.folderAdd: 4,
    TasteAction.scrolledPast: -0.3,
  };

  /// Under [RankingRules.hardNegatives] a negative weight is scaled by at most this, so one "Show less like this"
  /// keeps its force when the user has hundreds of positive signals.
  static const double negativeScale = interestWeight;
  static const double interestWeight = 4;
  static const double followWeight = 6;
  static const double halfLifeDays = 30;

  final Map<String, double> terms;
  final Map<String, double> creators;
  final bool hardNegatives;

  double get _maxTerm => terms.values.fold(1, max);
  double get _maxCreator => creators.values.fold(1, max);

  /// Sum of matched term weights, scaled so the strongest term counts 1.
  /// A taste term matches an item term that contains it ("space" hits "deep space").
  double termAffinity(Iterable<String> itemTerms) {
    if (terms.isEmpty) {
      return 0;
    }
    final double scale = _maxTerm;
    final double negative = hardNegatives ? min(scale, negativeScale) : scale;
    double sum = 0;
    for (final MapEntry<String, double> entry in terms.entries) {
      if (itemTerms.any((term) => term.contains(entry.key))) {
        sum += entry.value / (entry.value < 0 ? negative : scale);
      }
    }
    return sum.clamp(-2, 2).toDouble();
  }

  double creatorAffinity(String? creator) {
    if (creator == null) {
      return 0;
    }
    final double? weight = creators[creator];
    if (weight == null) {
      return 0;
    }
    final double scale = weight < 0 && hardNegatives ? min(_maxCreator, negativeScale) : _maxCreator;
    return (weight / scale).clamp(-1, 1).toDouble();
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
