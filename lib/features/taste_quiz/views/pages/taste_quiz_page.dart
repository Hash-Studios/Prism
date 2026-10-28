import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/views/widgets/taste_quiz_view.dart';
import 'package:flutter/material.dart';

/// Runs the quiz again for a user who finished onboarding. It adds to the signals they already have.
/// The route returns true when the user answered every round.
Future<bool?> openTasteQuizRetake(BuildContext context, {required TasteQuizPlan plan}) => Navigator.of(
  context,
  rootNavigator: true,
).push<bool>(MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => TasteQuizPage(plan: plan)));

class TasteQuizPage extends StatelessWidget {
  const TasteQuizPage({super.key, required this.plan});

  final TasteQuizPlan plan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: TasteQuizView(
        plan: plan,
        source: TasteQuizSource.retake,
        onFinished: (completed) => Navigator.of(context).pop(completed),
      ),
    );
  }
}
