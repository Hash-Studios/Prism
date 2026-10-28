part of 'taste_quiz_bloc.j.dart';

@freezed
abstract class TasteQuizEvent with _$TasteQuizEvent {
  /// [round] is the round the user saw, so a late second tap on the same pair is ignored.
  const factory TasteQuizEvent.picked({required int round, required QuizSide side}) = _Picked;
  const factory TasteQuizEvent.skipped() = _Skipped;

  /// The quiz measured how a shown wall looks, keyed by [QuizWall.key].
  const factory TasteQuizEvent.looked({required String key, required WallLook look}) = _Looked;

  /// "Tuning your feed" has been on screen long enough.
  const factory TasteQuizEvent.tuningShown() = _TuningShown;
}
