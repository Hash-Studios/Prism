import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

/// How bright a wall looks overall.
enum QuizTone { dark, light }

/// How much is going on in a wall.
enum QuizDensity { minimal, busy }

/// The colour temperature of a wall.
enum QuizMood { warm, cool, mono }

enum QuizSide {
  left,
  right;

  String get wireValue => name;
}

enum TasteQuizSource {
  onboarding,
  retake;

  String get wireValue => name;
}

/// A wall the quiz can show, with the traits its pairs contrast on. A null trait is unknown.
class QuizWall {
  const QuizWall({
    required this.item,
    required this.category,
    required this.wildCard,
    required this.terms,
    this.tone,
    this.density,
    this.mood,
  });

  final FeedItemEntity item;

  /// The category the wall was loaded from.
  final String category;

  /// From a category the user did not pick.
  final bool wildCard;

  /// Taste terms: tags, collections and [category], as the ranker reads them.
  final List<String> terms;
  final QuizTone? tone;
  final QuizDensity? density;
  final QuizMood? mood;

  String get key => item.canonicalKey;
}

class QuizRound {
  const QuizRound({required this.left, required this.right});

  final QuizWall left;
  final QuizWall right;

  bool get wildCard => left.wildCard;

  QuizWall wallAt(QuizSide side) => side == QuizSide.left ? left : right;
}

/// Every round, chosen before round 1.
class TasteQuizPlan {
  const TasteQuizPlan({required this.rounds});

  final List<QuizRound> rounds;
}

class QuizPick {
  const QuizPick({required this.round, required this.side});

  final QuizRound round;
  final QuizSide side;

  QuizWall get picked => round.wallAt(side);
  QuizWall get passed => round.wallAt(side == QuizSide.left ? QuizSide.right : QuizSide.left);

  /// A pick counts like a favourite. The wall that lost is a weak negative.
  List<TasteSignal> signals(DateTime at) {
    final TasteSignal favourite = TasteSignal.forWallpaper(
      TasteAction.favourite,
      picked.item.wallpaperCore,
      tags: picked.terms,
      at: at,
    );
    final TasteSignal passedOver = TasteSignal.forWallpaper(
      TasteAction.passedOver,
      passed.item.wallpaperCore,
      tags: passed.terms,
      at: at,
    );
    final Set<String> pickedTerms = favourite.terms.toSet();
    return <TasteSignal>[
      favourite,
      TasteSignal(
        action: passedOver.action,
        at: passedOver.at,
        terms: passedOver.terms.where((term) => !pickedTerms.contains(term)).toList(growable: false),
        creator: passedOver.creator,
      ),
    ];
  }
}
