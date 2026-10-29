import 'package:Prism/features/weekly_challenges/biz/weekly_challenges_cubit.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/features/weekly_challenges/views/pages/weekly_challenge_page.dart';
import 'package:Prism/features/weekly_challenges/views/widgets/weekly_challenge_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'weekly_challenges_cubit_test.dart' show Repository, challenge, entry;

class MockChallengeCubit extends MockCubit<WeeklyChallengesState> implements WeeklyChallengesCubit {}

Widget app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
void main() {
  for (final state in [ChallengeState.open, ChallengeState.votingClosed, ChallengeState.archived]) {
    testWidgets('page renders $state with empty entries and past winners', (tester) async {
      final cubit = MockChallengeCubit();
      when(() => cubit.state).thenReturn(
        WeeklyChallengesState(
          loading: false,
          detail: ChallengeDetail(
            challenge: challenge(state: state),
            entries: [],
            myEntryCount: 0,
          ),
          past: [
            WeeklyChallenge(
              id: '2026-10-19',
              theme: 'Morning light',
              state: ChallengeState.archived,
              opensAt: DateTime.utc(2026, 10, 19),
              closesAt: DateTime.utc(2026, 10, 26),
              winner: entry(),
            ),
          ],
        ),
      );
      when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
      await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-26', cubit: cubit)));
      expect(find.text('Quiet oceans'), findsOneWidget);
      expect(find.text('Upload an entry'), state == ChallengeState.open ? findsOneWidget : findsNothing);
      expect(find.text('Approved entries will appear here.'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      expect(find.text('Winner · Maya'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('error page provides retry', (tester) async {
    final cubit = MockChallengeCubit();
    when(() => cubit.state).thenReturn(const WeeklyChallengesState(loading: false, failed: true));
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-26', cubit: cubit)));
    expect(find.text('We could not load this challenge. Try again.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => cubit.load('2026-10-26')).called(2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('home card appears only inside the UTC open window', (tester) async {
    final cubit = WeeklyChallengesCubit(Repository());
    addTearDown(cubit.close);
    await tester.pumpWidget(app(WeeklyChallengeCard(cubit: cubit, now: () => DateTime.utc(2026))));
    await tester.pump();
    expect(find.text('Weekly challenge'), findsOneWidget);
    await tester.pumpWidget(
      app(WeeklyChallengeCard(key: const ValueKey('closed'), cubit: cubit, now: () => DateTime.utc(2100))),
    );
    await tester.pump();
    expect(find.text('Weekly challenge'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('returning from the background reloads challenge visibility', (tester) async {
    final cubit = MockChallengeCubit();
    when(() => cubit.state).thenReturn(const WeeklyChallengesState());
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-26', cubit: cubit)));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    verify(() => cubit.load('2026-10-26')).called(2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('large text leaves the theme and entry actions readable', (tester) async {
    final cubit = MockChallengeCubit();
    when(() => cubit.state).thenReturn(
      WeeklyChallengesState(
        loading: false,
        detail: ChallengeDetail(challenge: challenge(), entries: [], myEntryCount: 3),
      ),
    );
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    await tester.pumpWidget(
      app(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: WeeklyChallengePage(challengeId: '2026-10-26', cubit: cubit),
        ),
      ),
    );
    expect(find.text('You have entered 3 wallpapers in this challenge.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
