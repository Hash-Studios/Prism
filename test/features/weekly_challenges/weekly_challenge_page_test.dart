import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/weekly_challenges/biz/weekly_challenges_cubit.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/features/weekly_challenges/views/pages/weekly_challenge_page.dart';
import 'package:Prism/features/weekly_challenges/views/widgets/weekly_challenge_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  ChallengeTestRouter({this.home = const SizedBox()});
  final Widget home;
  @override
  RouteType get defaultRouteType => AppRouter().defaultRouteType;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo('Blank', builder: (_) => home),
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
        final button = find.widgetWithText(PrismButton, 'Upload an entry');
        if (count == 3) {
          expect(tester.widget<PrismButton>(button).onPressed, isNull);
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

  testWidgets('the open link pushes a new page without changing Home, in RTL with reduced motion', (tester) async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    final repo = Repository();
    final ended = challenge(state: ChallengeState.archived);
    final open = WeeklyChallenge(
      id: 'other',
      theme: 'Open theme',
      state: ChallengeState.open,
      opensAt: DateTime.utc(2020),
      closesAt: DateTime.utc(2100),
    );
    repo.detail = ChallengeDetail(challenge: ended, entries: [], myEntryCount: 0);
    repo.openList = () async => [open];
    final cubits = <WeeklyChallengesCubit>[];
    getIt.registerFactory<WeeklyChallengesCubit>(() {
      final cubit = WeeklyChallengesCubit(repo);
      cubits.add(cubit);
      return cubit;
    });
    addTearDown(getIt.reset);
    final router = ChallengeTestRouter(home: const Scaffold(body: WeeklyChallengeCard()));
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(cubits, hasLength(1));
    unawaited(router.push(WeeklyChallengeRoute(challengeId: ended.id)));
    await tester.pumpAndSettle();
    expect(cubits, hasLength(2));
    expect(cubits.first.state.current, same(open));
    final link = find.widgetWithText(PrismRow, open.theme);
    expect(link, findsOneWidget);
    final leading = find.descendant(of: link, matching: find.byIcon(Icons.emoji_events_rounded));
    final chevron = find.descendant(of: link, matching: find.byIcon(Icons.chevron_right_rounded));
    expect(tester.getCenter(leading).dx, greaterThan(tester.getCenter(chevron).dx));
    expect(Icons.chevron_right_rounded.matchTextDirection, isTrue);
    repo.detail = ChallengeDetail(challenge: open, entries: [], myEntryCount: 0);
    await tester.tap(link);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getTopLeft(find.byType(WeeklyChallengePage).last).dx, 0);
    await tester.pumpAndSettle();
    expect(router.stack.where((r) => r.name == WeeklyChallengeRoute.name), hasLength(2));
    expect(tester.widget<WeeklyChallengePage>(find.byType(WeeklyChallengePage)).challengeId, open.id);
    expect(cubits, hasLength(3));
    expect(cubits.first.state.current, same(open));
    expect(cubits[1].state.detail!.challenge, same(ended));
    expect(cubits.last.state.detail!.challenge, same(open));
    await router.maybePop();
    await tester.pumpAndSettle();
    expect(tester.widget<WeeklyChallengePage>(find.byType(WeeklyChallengePage)).challengeId, ended.id);
    await tester.pumpWidget(const SizedBox());
  });

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
  testWidgets('an empty week shows last week top entries above the empty message', (tester) async {
    final cubit = MockChallengeCubit();
    final past = WeeklyChallenge(
      id: '2026-10-19',
      theme: 'Morning light',
      state: ChallengeState.archived,
      opensAt: DateTime.utc(2026, 10, 19),
      closesAt: DateTime.utc(2026, 10, 26),
    );
    when(() => cubit.state).thenReturn(
      WeeklyChallengesState(
        loading: false,
        detail: ChallengeDetail(challenge: challenge(), entries: [], myEntryCount: 0),
        past: [past],
      ),
    );
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    when(() => cubit.topEntries('2026-10-19')).thenAnswer((_) async => [entry(), entry()]);
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-26', cubit: cubit)));
    await tester.pump();
    expect(find.text('Morning light'), findsWidgets);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Approved entries will appear here.', skipOffstage: false), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty week hides Top/New and keeps the current challenge out of Past', (tester) async {
    final cubit = MockChallengeCubit();
    final current = challenge();
    when(() => cubit.state).thenReturn(
      WeeklyChallengesState(
        loading: false,
        detail: ChallengeDetail(challenge: current, entries: [], myEntryCount: 0),
        past: [current],
      ),
    );
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: current.id, cubit: cubit)));
    await tester.pump();
    expect(find.byType(PrismSegmented<ChallengeSort>), findsNothing);
    expect(find.byType(PrismGroup, skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an ended challenge with no entries links to the open challenge instead of an empty state', (
    tester,
  ) async {
    final cubit = MockChallengeCubit();
    final ended = WeeklyChallenge(
      id: '2026-10-19',
      theme: 'Morning light',
      state: ChallengeState.archived,
      opensAt: DateTime.utc(2026, 10, 19),
      closesAt: DateTime.utc(2026, 10, 26),
    );
    when(() => cubit.state).thenReturn(
      WeeklyChallengesState(
        loading: false,
        detail: ChallengeDetail(challenge: ended, entries: [], myEntryCount: 0),
        current: challenge(),
        past: [ended],
      ),
    );
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: ended.id, cubit: cubit)));
    await tester.pump();
    expect(find.widgetWithText(PrismRow, 'Quiet oceans'), findsOneWidget);
    expect(find.text('Upload an entry'), findsOneWidget);
    expect(find.text('Approved entries will appear here.', skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an ended page refreshes when its linked open challenge closes', (tester) async {
    final cubit = MockChallengeCubit();
    final states = StreamController<WeeklyChallengesState>();
    addTearDown(states.close);
    whenListen(cubit, states.stream, initialState: const WeeklyChallengesState());
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: 'ended', cubit: cubit)));
    states.add(
      WeeklyChallengesState(
        loading: false,
        detail: ChallengeDetail(
          challenge: challenge(state: ChallengeState.archived),
          entries: [],
          myEntryCount: 0,
        ),
        current: WeeklyChallenge(
          id: 'closing',
          theme: 'Closing soon',
          state: ChallengeState.open,
          opensAt: DateTime.utc(2020),
          closesAt: DateTime.now().toUtc().add(const Duration(seconds: 10)),
        ),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(PrismRow, 'Closing soon'), findsOneWidget);
    verify(() => cubit.load('ended')).called(1);
    await tester.pump(const Duration(seconds: 11));
    verify(() => cubit.load('ended')).called(1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('last-week thumbnail failures show a themed fallback without an image error', (tester) async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final cubit = MockChallengeCubit();
    final past = WeeklyChallenge(
      id: '2026-10-19',
      theme: 'Morning light',
      state: ChallengeState.archived,
      opensAt: DateTime.utc(2026, 10, 19),
      closesAt: DateTime.utc(2026, 10, 26),
    );
    when(() => cubit.state).thenReturn(
      WeeklyChallengesState(
        loading: false,
        detail: ChallengeDetail(challenge: challenge(), entries: [], myEntryCount: 0),
        past: [past],
      ),
    );
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    when(() => cubit.topEntries(past.id)).thenAnswer((_) async => [entry()]);
    final imageLoad = Completer<ImageInfo>();
    final imageKey = await const CachedNetworkImageProvider('').obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(imageKey, () => OneFrameImageStreamCompleter(imageLoad.future));
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-26', cubit: cubit)));
    await tester.pump();
    imageLoad.completeError(const SocketException('offline'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byType(CachedNetworkImage), matching: find.byType(ColoredBox)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
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
      when(() => cubit.topEntries(any())).thenAnswer((_) async => const []);
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

  testWidgets('the two entry buttons share the row width', (tester) async {
    final cubit = MockChallengeCubit();
    when(() => cubit.state).thenReturn(
      WeeklyChallengesState(
        loading: false,
        detail: ChallengeDetail(challenge: challenge(), entries: [], myEntryCount: 0),
      ),
    );
    when(() => cubit.load(any(), sort: any(named: 'sort'))).thenAnswer((_) async {});
    await tester.pumpWidget(app(WeeklyChallengePage(challengeId: '2026-10-26', cubit: cubit)));
    final Finder buttons = find.byType(PrismButton);
    expect(buttons, findsNWidgets(2));
    expect(tester.getSize(buttons.at(0)).width, tester.getSize(buttons.at(1)).width);
    await tester.pumpWidget(const SizedBox());
  });
}
