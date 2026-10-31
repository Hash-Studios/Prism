import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/weekly_challenges/biz/weekly_challenges_cubit.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/features/weekly_challenges/views/pages/weekly_challenge_page.dart';
import 'package:Prism/features/weekly_challenges/views/widgets/weekly_challenge_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import 'weekly_challenges_cubit_test.dart' show Repository, challenge, entry;

class MockChallengeCubit extends MockCubit<WeeklyChallengesState> implements WeeklyChallengesCubit {}

Widget app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

class ChallengeTestRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo('Blank', builder: (_) => const SizedBox()),
    ),
    AutoRoute(path: '/challenges/:challengeId', page: WeeklyChallengeRoute.page),
  ];
}

void main() {
  for (final premium in [false, true]) {
    for (final (count, remainingFree, expected) in [
      (0, 3, 3),
      (1, 3, 2),
      (2, 3, 1),
      (3, 3, 0),
      (0, 1, 1),
      (0, 0, 0),
      (1, 1, 1),
    ]) {
      testWidgets('picker respects remaining lifetime slots: premium=$premium entries=$count free=$remainingFree', (
        tester,
      ) async {
        final previousUser = app_state.prismUser;
        const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
        int singleCalls = 0;
        final multiLimits = <int?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pickerChannel, (call) async {
          if (call.method == 'pickImage') {
            singleCalls++;
            return null;
          }
          if (call.method == 'pickMultiImage') {
            multiLimits.add((call.arguments as Map)['limit'] as int?);
            return <String>[];
          }
          throw StateError('Unexpected picker method: ${call.method}');
        });
        app_state.prismUser = app_constants.createGuestPrismUser()
          ..loggedIn = true
          ..premium = premium;
        final settings = SettingsLocalDataSource(InMemoryLocalStore());
        getIt.registerSingleton<SettingsLocalDataSource>(settings);
        await tester.runAsync(() async {
          for (var used = remainingFree; used < UploadQuota.freeUploadsPerWeek; used++) {
            await UploadQuota.incrementWeeklyUploads();
          }
        });
        const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
        addTearDown(() async {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pickerChannel, null);
          app_state.prismUser = previousUser;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
          await getIt.reset();
        });
        final cubit = MockChallengeCubit();
        when(() => cubit.state).thenReturn(
          WeeklyChallengesState(
            loading: false,
            detail: ChallengeDetail(challenge: challenge(), entries: [], myEntryCount: count),
          ),
        );
        when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
        await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-26', cubit: cubit)));
        final button = find.widgetWithText(FilledButton, 'Upload an entry');
        if (count == 3) {
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
        } else {
          await tester.tap(button);
          await tester.pump();
        }
        final limit = premium ? 3 - count : expected;
        expect(singleCalls, limit == 1 ? 1 : 0);
        expect(multiLimits, limit > 1 ? [limit] : isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }

  testWidgets('warm navigate replaces challenge ID on the same page state', (tester) async {
    final cubit = MockChallengeCubit();
    when(() => cubit.state).thenReturn(const WeeklyChallengesState());
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    final router = ChallengeTestRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    unawaited(router.navigate(WeeklyChallengeRoute(challengeId: '2026-10-19', cubit: cubit)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final oldState = tester.state(find.byType(WeeklyChallengePage));
    verify(() => cubit.load('2026-10-19')).called(1);
    unawaited(router.navigate(WeeklyChallengeRoute(challengeId: '2026-10-26', cubit: cubit)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<WeeklyChallengePage>(find.byType(WeeklyChallengePage)).challengeId, '2026-10-26');
    expect(tester.state(find.byType(WeeklyChallengePage)), same(oldState));
    verify(() => cubit.load('2026-10-26')).called(1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('ID replacement cancels the old deadline and resets winner impressions', (tester) async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);
    final cubit = MockChallengeCubit();
    final states = StreamController<WeeklyChallengesState>();
    addTearDown(states.close);
    whenListen(cubit, states.stream, initialState: const WeeklyChallengesState());
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    WeeklyChallengesState winner(String id, {bool open = false}) => WeeklyChallengesState(
      loading: false,
      detail: ChallengeDetail(
        challenge: WeeklyChallenge(
          id: id,
          theme: id,
          state: open ? ChallengeState.open : ChallengeState.archived,
          opensAt: DateTime.now().subtract(const Duration(days: 1)),
          closesAt: DateTime.now().add(const Duration(seconds: 10)),
          winner: entry(),
        ),
        entries: [],
        myEntryCount: 0,
      ),
    );
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-19', cubit: cubit)));
    states.add(winner('2026-10-19', open: true));
    await tester.pump();
    states.add(winner('2026-10-19', open: true));
    await tester.pump();
    expect(analytics.events.where((e) => e.eventName == 'challenge_winner_viewed'), hasLength(1));
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-26', cubit: cubit)));
    await tester.pump(const Duration(seconds: 11));
    verify(() => cubit.load('2026-10-26')).called(1);
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-19', cubit: cubit)));
    states.add(winner('2026-10-19'));
    await tester.pump();
    expect(analytics.events.where((e) => e.eventName == 'challenge_winner_viewed'), hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });
  test('vote counts use localized singular and plural forms', () {
    final expected = <String, List<String>>{
      'en': ['0 votes', '1 vote', '2 votes'],
      'de': ['0 Stimmen', '1 Stimme', '2 Stimmen'],
      'es': ['0 votos', '1 voto', '2 votos'],
      'pt': ['0 votos', '1 voto', '2 votos'],
      'pt_BR': ['0 votos', '1 voto', '2 votos'],
      'hi': ['0 वोट', '1 वोट', '2 वोट'],
      'id': ['0 suara', '1 suara', '2 suara'],
    };
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect([
        for (final count in [0, 1, 2]) l10n.challengeVotes(count),
      ], expected[locale.toString()]);
    }
  });
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
