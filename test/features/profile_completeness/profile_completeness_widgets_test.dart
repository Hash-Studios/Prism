import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_card.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_nudge_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('card renders percent ring label and missing-step text', (tester) async {
    const status = ProfileCompletenessStatus(
      completedSteps: 2,
      totalSteps: 4,
      progress: 0.5,
      percent: 50,
      missingSteps: <ProfileCompletenessStep>[ProfileCompletenessStep.bio, ProfileCompletenessStep.socialLink],
    );

    await tester.pumpWidget(_wrap(const ProfileCompletenessCard(status: status)));

    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('card is hidden when status is 100% complete', (tester) async {
    const status = ProfileCompletenessStatus(
      completedSteps: 4,
      totalSteps: 4,
      progress: 1,
      percent: 100,
      missingSteps: <ProfileCompletenessStep>[],
    );

    await tester.pumpWidget(_wrap(const ProfileCompletenessCard(status: status)));

    expect(find.text('Profile completeness'), findsNothing);
    expect(find.byType(ProfileCompletenessCard), findsOneWidget);
  });

  testWidgets('card CTA invokes edit action callback', (tester) async {
    bool tapped = false;
    const status = ProfileCompletenessStatus(
      completedSteps: 1,
      totalSteps: 4,
      progress: 0.25,
      percent: 25,
      missingSteps: <ProfileCompletenessStep>[
        ProfileCompletenessStep.username,
        ProfileCompletenessStep.bio,
        ProfileCompletenessStep.socialLink,
      ],
    );

    await tester.pumpWidget(
      _wrap(
        ProfileCompletenessCard(
          status: status,
          onCompleteNow: () async {
            tapped = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('sheet renders progress and missing-step text', (tester) async {
    const status = ProfileCompletenessStatus(
      completedSteps: 3,
      totalSteps: 4,
      progress: 0.75,
      percent: 75,
      missingSteps: <ProfileCompletenessStep>[ProfileCompletenessStep.socialLink],
    );

    await tester.pumpWidget(_wrap(const ProfileCompletenessNudgeSheet(status: status)));

    expect(find.textContaining('75% complete'), findsOneWidget);
    expect(find.text('Add one social link'), findsOneWidget);
  });
}
