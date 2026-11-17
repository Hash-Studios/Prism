import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/logger/logger.dart';

/// The For you ranker rules taken from X's 2026 feed algorithm (docs/research/x-algorithm-2026.md).
/// [legacy] turns every rule off and gives the ranker that shipped before them, order for order.
class RankingRules {
  const RankingRules({
    this.hardNegatives = false,
    this.newActions = false,
    this.scrolledPast = false,
    this.dedupeVariants = false,
  });

  static const RankingRules legacy = RankingRules();
  static const RankingRules x2026 = RankingRules(
    hardNegatives: true,
    newActions: true,
    scrolledPast: true,
    dedupeVariants: true,
  );

  /// Remote Config switch. Off gives [legacy].
  static const String remoteConfigKey = 'feed_ranker_x2026_enabled';
  static const bool defaultEnabled = true;

  static RankingRules fromFlag(bool enabled) => enabled ? x2026 : legacy;

  /// The rules the Remote Config flag picks now. An unreadable flag gives the default.
  static RankingRules get current {
    bool enabled = defaultEnabled;
    try {
      enabled = FirebaseInit.remoteConfigIfInitialized?.getBool(remoteConfigKey) ?? enabled;
    } catch (error) {
      logger.w('[PersonalizedFeed] ranker flag unreadable, using the default: $error');
    }
    return fromFlag(enabled);
  }

  /// A negative term or creator keeps its full weight when the user has many positive signals.
  final bool hardNegatives;

  /// Share and folder add count as taste actions.
  final bool newActions;

  /// A wall that an earlier feed load showed, and that the user never acted on, teaches a small negative once.
  final bool scrolledPast;

  /// One wall per light/dark group in a page and across the pages of one session.
  final bool dedupeVariants;
}
