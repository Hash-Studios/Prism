part of 'taste_quiz_bloc.j.dart';

@freezed
sealed class TasteQuizState with _$TasteQuizState {
  /// The round on screen is `plan.rounds[picks.length]`.
  const factory TasteQuizState.playing({required TasteQuizPlan plan, required List<QuizPick> picks}) = TasteQuizPlaying;

  /// The walls the ranker now puts first, and what the picks say.
  const factory TasteQuizState.tuning({required List<FeedItemEntity> walls, required TasteSummary summary}) =
      TasteQuizTuning;

  /// [completed] is false when the user skipped.
  const factory TasteQuizState.finished({required bool completed}) = TasteQuizFinished;
}
