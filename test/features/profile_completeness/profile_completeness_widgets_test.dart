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
      missingSteps: <ProfileCompletenessStep>[ProfileCompletenessStep.bio, ProfileCompletenessStep.socialLink],
    );

    await tester.pumpWidget(_wrap(ProfileCompletenessCard(status: status, onCompleteNow: () async {})));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Profile 50% done'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('2 steps · '), findsOneWidget);
  });

  testWidgets('card says 1 step when one is left', (tester) async {
    const status = ProfileCompletenessStatus(missingSteps: <ProfileCompletenessStep>[ProfileCompletenessStep.bio]);

    await tester.pumpWidget(_wrap(ProfileCompletenessCard(status: status, onCompleteNow: () async {})));

    expect(find.text('1 step · '), findsOneWidget);
  });

  testWidgets('card CTA invokes edit action callback', (tester) async {
    bool tapped = false;
    const status = ProfileCompletenessStatus(
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

  testWidgets('sheet renders progress and missing-step text, and answers with the tapped action', (tester) async {
    const status = ProfileCompletenessStatus(
      missingSteps: <ProfileCompletenessStep>[ProfileCompletenessStep.socialLink],
    );
    ProfileCompletenessNudgeAction? answer;

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await showProfileCompletenessNudgeSheet(context, status: status),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('75% complete'), findsOneWidget);
    expect(find.text('Add one social link'), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.text('Add one social link')))! as ModalBottomSheetRoute;
    expect(route.useSafeArea, isTrue);
    expect(route.isDismissible, isFalse);
    expect(route.enableDrag, isFalse);

    await tester.tap(find.text('Complete now'));
    await tester.pumpAndSettle();

    expect(answer, ProfileCompletenessNudgeAction.completeNow);
  });
}
