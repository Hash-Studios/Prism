part of 'taste_quiz_bloc.j.dart';

@freezed
sealed class TasteQuizState with _$TasteQuizState {
  /// The round on screen is `plan.rounds[picks.length]`.
  const factory TasteQuizState.playing({required TasteQuizPlan plan, required List<QuizPick> picks}) = TasteQuizPlaying;

  /// What the picks say, and the first walls of the real For you feed. [walls] is null while the feed loads, and
  /// empty when it did not load in time.
  const factory TasteQuizState.tuning({required TasteSummary summary, List<FeedItemEntity>? walls}) = TasteQuizTuning;

  /// [completed] is false when the user skipped.
  const factory TasteQuizState.finished({required bool completed}) = TasteQuizFinished;
}
