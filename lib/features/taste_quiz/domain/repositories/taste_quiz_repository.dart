import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';

abstract class TasteQuizRepository {
  /// Loads walls from the [interests] categories and a few others, and plans the rounds.
  /// Returns null when the walls do not load in time or there are too few. It never throws.
  Future<TasteQuizPlan?> loadPlan(List<String> interests);
}
