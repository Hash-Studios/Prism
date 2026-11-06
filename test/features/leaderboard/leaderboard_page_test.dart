import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/leaderboard/biz/bloc/leaderboard_bloc.j.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/views/pages/leaderboard_page.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockBloc extends MockBloc<LeaderboardEvent, LeaderboardState> implements LeaderboardBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

const LeaderboardEntry _ana = LeaderboardEntry(
  uid: 'a',
  name: 'Ana',
  username: 'ana',
  photo: '',
  xp: 1200,
  rank: 'silver',
);
const LeaderboardEntry _me = LeaderboardEntry(
  uid: 'me',
  name: 'Me',
  username: 'me_user',
  photo: '',
  xp: 40,
  rank: 'bronze',
  isMe: true,
);

void main() {
  late _MockBloc bloc;
  late _MockStackRouter router;
  late FakeAppAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(const LeaderboardEvent.started());
    registerFallbackValue(ProfileRoute());
  });

  setUp(() {
    bloc = _MockBloc();
    router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(AnalyticsRuntime.reset);

  Future<void> pumpPage(
    WidgetTester tester,
    LeaderboardState state, {
    Stream<LeaderboardState> states = const Stream<LeaderboardState>.empty(),
    double textScale = 1,
  }) {
    whenListen(bloc, states, initialState: state);
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<LeaderboardBloc>.value(value: bloc, child: const LeaderboardPage()),
        ),
      ),
    );
  }

  LeaderboardState loaded({
    LeaderboardTab tab = LeaderboardTab.global,
    List<LeaderboardEntry> global = const <LeaderboardEntry>[_ana, _me],
    List<LeaderboardEntry> friends = const <LeaderboardEntry>[],
  }) => LeaderboardState.initial().copyWith(
    tab: tab,
    friendsStatus: LoadStatus.success,
    globalStatus: LoadStatus.success,
    global: global,
    friends: friends,
  );

  testWidgets('lists ranked rows with xp, rank tags and the reset caption', (tester) async {
    await pumpPage(tester, loaded());

    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Friends'), findsNothing);
    expect(find.text('Ranked by XP earned this week'), findsNothing);
    expect(find.textContaining('Resets in '), findsOneWidget);
    expect(find.text('Top 50 · updated about every 3 hours'), findsNothing);
    expect(find.textContaining('pull to refresh'), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text(AppLocalizationsEn().economyXp(1200)), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(PrismSegmented<LeaderboardTab>), findsOneWidget);
  });

  testWidgets('a row passes the frame and the premium flag to the avatar', (tester) async {
    const LeaderboardEntry framed = LeaderboardEntry(
      uid: 'p',
      name: 'Pia',
      username: 'pia',
      photo: '',
      xp: 300,
      rank: 'gold',
      frameId: 'frame_prism',
      premium: true,
    );
    await pumpPage(tester, loaded(global: const <LeaderboardEntry>[framed]));

    final PrismAvatar avatar = tester.widget<PrismAvatar>(find.byType(PrismAvatar));
    expect(avatar.frameId, 'frame_prism');
    expect(avatar.premium, isTrue);
  });

  testWidgets('tapping a row opens the profile', (tester) async {
    await pumpPage(tester, loaded());

    await tester.tap(find.text('Ana'));

    final PageRouteInfo<dynamic> route = verify(() => router.push(captureAny())).captured.single as PageRouteInfo;
    expect(route, isA<ProfileRoute>());
    expect((route as ProfileRoute).args!.profileIdentifier, 'ana');
  });

  testWidgets('an empty friends tab asks the user to follow creators', (tester) async {
    await pumpPage(tester, loaded(tab: LeaderboardTab.friends));

    expect(find.text('Follow creators to see them here.'), findsOneWidget);
  });

  testWidgets('following cold start keeps my score and explains how to add comparisons', (tester) async {
    await pumpPage(
      tester,
      loaded(tab: LeaderboardTab.friends, friends: const <LeaderboardEntry>[_me], global: const <LeaderboardEntry>[]),
    );

    expect(find.text('40 XP'), findsOneWidget);
    expect(find.text('Your score is included. Follow creators to compare weekly XP.'), findsOneWidget);
    expect(find.text('Find creators'), findsOneWidget);
    expect(find.byIcon(Icons.group_add_rounded), findsOneWidget);
    expect(find.text('No rankings yet'), findsNothing);
  });

  testWidgets('a short following list shows the global top 5 and See all opens Global', (tester) async {
    final List<LeaderboardEntry> global = <LeaderboardEntry>[
      for (int i = 0; i < 7; i++)
        LeaderboardEntry(uid: 'g$i', name: 'Global $i', username: 'g$i', photo: '', xp: 900 - i, rank: 'gold'),
    ];
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpPage(tester, loaded(tab: LeaderboardTab.friends, friends: const <LeaderboardEntry>[_me], global: global));

    expect(find.text('Top this week'), findsOneWidget);
    for (int i = 0; i < 5; i++) {
      expect(find.text('Global $i'), findsOneWidget);
    }
    expect(find.text('Global 5'), findsNothing);
    // The tip comes before the global list.
    expect(
      tester.getTopLeft(find.text('Find creators')).dy,
      lessThan(tester.getTopLeft(find.text('Top this week')).dy),
    );

    await tester.tap(find.text('See all'));
    verify(() => bloc.add(const LeaderboardEvent.tabChanged(LeaderboardTab.global))).called(1);
    expect(analytics.events.whereType<LeaderboardViewedEvent>().map((e) => e.tab), <String>['friends', 'global']);
  });

  testWidgets('the global top list waits for the global board to load', (tester) async {
    await pumpPage(
      tester,
      loaded(
        tab: LeaderboardTab.friends,
        friends: const <LeaderboardEntry>[_me],
        global: const <LeaderboardEntry>[_ana],
      ).copyWith(globalStatus: LoadStatus.loading),
    );

    expect(find.text('Find creators'), findsOneWidget);
    expect(find.text('Top this week'), findsNothing);
    expect(find.text('See all'), findsNothing);
  });

  testWidgets('Find creators opens the creators page', (tester) async {
    await pumpPage(
      tester,
      loaded(tab: LeaderboardTab.friends, friends: const <LeaderboardEntry>[_me], global: const <LeaderboardEntry>[]),
    );

    await tester.tap(find.text('Find creators'));

    final PageRouteInfo<dynamic> route = verify(() => router.push(captureAny())).captured.single as PageRouteInfo;
    expect(route, isA<CreatorsRoute>());
  });

  testWidgets('five or more following rows show no find-creators prompt', (tester) async {
    final List<LeaderboardEntry> five = <LeaderboardEntry>[
      _me,
      for (int i = 0; i < 4; i++)
        LeaderboardEntry(uid: 'u$i', name: 'User $i', username: 'u$i', photo: '', xp: 10 + i, rank: 'bronze'),
    ];
    await pumpPage(tester, loaded(tab: LeaderboardTab.friends, friends: five));

    expect(find.text('Find creators'), findsNothing);
    expect(find.text('Top this week'), findsNothing);
  });

  testWidgets('scoring explanation separates weekly positions, lifetime ranks and tab rules', (tester) async {
    await pumpPage(tester, loaded());
    await tester.tap(find.byTooltip('How leaderboard scoring works'));
    await tester.pumpAndSettle();

    expect(find.text('Ranked by XP earned this week'), findsOneWidget);
    expect(find.textContaining('Rank labels, such as Silver, use lifetime XP.'), findsOneWidget);
    expect(find.textContaining('Weekly XP resets Monday at 00:00 UTC; lifetime XP and rank stay.'), findsOneWidget);
    expect(find.textContaining('first 90 accounts you follow'), findsOneWidget);
    expect(find.textContaining('there is no minimum account age'), findsOneWidget);
    expect(find.textContaining('Scores load when you first open this tab. Pull to refresh.'), findsOneWidget);
    expect(find.textContaining('Accounts must be at least 7 days old'), findsOneWidget);
    expect(find.textContaining('new XP may take time to appear'), findsOneWidget);
    expect(find.textContaining('Pulling to refresh loads the latest snapshot.'), findsOneWidget);
    expect(find.text('If you are offline, saved scores may be shown.'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('How scoring works'), findsNothing);
  });

  testWidgets('tab changes replace following guidance and rows with the global snapshot', (tester) async {
    final StreamController<LeaderboardState> states = StreamController<LeaderboardState>.broadcast(sync: true);
    addTearDown(states.close);
    await pumpPage(
      tester,
      loaded(tab: LeaderboardTab.friends, friends: const <LeaderboardEntry>[_me], global: const <LeaderboardEntry>[]),
      states: states.stream,
    );

    await tester.tap(find.text('Global'));
    verify(() => bloc.add(const LeaderboardEvent.tabChanged(LeaderboardTab.global))).called(1);
    states.add(loaded(global: const <LeaderboardEntry>[_ana]));
    await tester.pump();

    expect(find.text(AppLocalizationsEn().economyXp(1200)), findsOneWidget);
    expect(find.text('40 XP'), findsNothing);
    expect(find.text('Find creators'), findsNothing);
    expect(find.text('Your score is included. Follow creators to compare weekly XP.'), findsNothing);

    await tester.tap(find.text('Following'));
    verify(() => bloc.add(const LeaderboardEvent.tabChanged(LeaderboardTab.friends))).called(1);
    states.add(
      loaded(tab: LeaderboardTab.friends, friends: const <LeaderboardEntry>[_me], global: const <LeaderboardEntry>[]),
    );
    await tester.pump();
    expect(find.text('40 XP'), findsOneWidget);
    expect(find.text('Find creators'), findsOneWidget);
  });

  testWidgets('scoring copy remains reachable on a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpPage(
      tester,
      loaded(tab: LeaderboardTab.friends, friends: const <LeaderboardEntry>[_me], global: const <LeaderboardEntry>[]),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('40 XP'), 150, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('How leaderboard scoring works'));
    // Glint loops, so pump a bounded time instead of settling.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('If you are offline, saved scores may be shown.'));
    // Glint loops, so pump a bounded time instead of settling.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('If you are offline, saved scores may be shown.').hitTestable(), findsOneWidget);
  });

  testWidgets('switching tabs sends the event and tracks the view', (tester) async {
    await pumpPage(
      tester,
      loaded(tab: LeaderboardTab.friends, friends: const <LeaderboardEntry>[_me], global: const <LeaderboardEntry>[]),
    );
    expect(analytics.events.whereType<LeaderboardViewedEvent>().single.tab, 'friends');

    await tester.tap(find.text('Global'));

    verify(() => bloc.add(const LeaderboardEvent.tabChanged(LeaderboardTab.global))).called(1);
    expect(analytics.events.whereType<LeaderboardViewedEvent>().map((e) => e.tab), <String>['friends', 'global']);
  });

  testWidgets('shows a retry state when the first load fails', (tester) async {
    await pumpPage(
      tester,
      LeaderboardState.initial().copyWith(globalStatus: LoadStatus.failure, tab: LeaderboardTab.global),
    );

    expect(find.text("Couldn't load the leaderboard"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  for (final LoadStatus status in <LoadStatus>[LoadStatus.initial, LoadStatus.loading]) {
    testWidgets('pulling the ${status.name} skeleton does not start an overlapping refresh', (tester) async {
      await pumpPage(tester, loaded(global: const <LeaderboardEntry>[]).copyWith(globalStatus: status));
      await tester.drag(find.textContaining('Resets in'), const Offset(0, 500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verifyNever(() => bloc.add(const LeaderboardEvent.refreshed()));
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });
  }

  for (final LoadStatus status in <LoadStatus>[LoadStatus.success, LoadStatus.failure]) {
    testWidgets('pulling the caption refreshes a ${status.name} board and completes', (tester) async {
      final StreamController<LeaderboardState> states = StreamController<LeaderboardState>.broadcast(sync: true);
      addTearDown(states.close);
      final LeaderboardState initial = loaded(global: const <LeaderboardEntry>[]).copyWith(globalStatus: status);
      await pumpPage(tester, initial, states: states.stream);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.drag(find.textContaining('Resets in'), const Offset(0, 500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      verify(() => bloc.add(const LeaderboardEvent.refreshed())).called(1);

      states.add(initial.copyWith(globalStatus: LoadStatus.loading));
      await tester.pump();
      states.add(loaded(global: const <LeaderboardEntry>[_ana]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(AppLocalizationsEn().economyXp(1200)), findsOneWidget);
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('resetCaption counts down to Monday 00:00 UTC', () {
    expect(resetCaption(AppLocalizationsEn(), DateTime.utc(2026, 10, 17, 20)), 'Resets in 1d 4h');
  });
}
