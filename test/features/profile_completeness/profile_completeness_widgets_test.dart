import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_card.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_nudge_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('card renders percent, reward line and the missing steps by name', (tester) async {
    const status = ProfileCompletenessStatus(
      missingSteps: <ProfileCompletenessStep>[ProfileCompletenessStep.bio, ProfileCompletenessStep.socialLink],
    );

    await tester.pumpWidget(_wrap(ProfileCompletenessCard(status: status, onCompleteNow: () async {})));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Earn 25 coins when you finish'), findsOneWidget);
    expect(find.text('Write bio'), findsOneWidget);
    expect(find.text('Add one social link'), findsOneWidget);
    expect(find.text('Add profile photo'), findsNothing);
  });

  testWidgets('card fills its progress bar to the completed share', (tester) async {
    const status = ProfileCompletenessStatus(missingSteps: <ProfileCompletenessStep>[ProfileCompletenessStep.bio]);

    await tester.pumpWidget(_wrap(ProfileCompletenessCard(status: status, onCompleteNow: () async {})));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.75);
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

    await tester.tap(find.text('Complete profile'));
    await tester.pump(const Duration(milliseconds: 400));

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
    // Glint loops, so pump a bounded time instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Finish your profile'), findsOneWidget);
    expect(find.textContaining('75% complete'), findsOneWidget);
    expect(find.textContaining('25 Prism coins'), findsOneWidget);
    expect(find.text('Add one social link'), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.text('Add one social link')))! as ModalBottomSheetRoute;
    expect(route.useSafeArea, isTrue);
    expect(route.isDismissible, isFalse);
    expect(route.enableDrag, isFalse);

    await tester.tap(find.text('Complete profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(answer, ProfileCompletenessNudgeAction.completeNow);
  });

  testWidgets('sheet answers "not now" from the Later button', (tester) async {
    const status = ProfileCompletenessStatus(missingSteps: <ProfileCompletenessStep>[ProfileCompletenessStep.bio]);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Later'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(answer, ProfileCompletenessNudgeAction.notNow);
  });
}
