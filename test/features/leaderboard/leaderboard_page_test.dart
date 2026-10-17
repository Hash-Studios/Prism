import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/leaderboard/biz/bloc/leaderboard_bloc.j.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/views/pages/leaderboard_page.dart';
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

  Future<void> pumpPage(WidgetTester tester, LeaderboardState state) {
    whenListen(bloc, const Stream<LeaderboardState>.empty(), initialState: state);
    return tester.pumpWidget(
      MaterialApp(
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
    expect(find.textContaining('Resets Monday · '), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('1200 XP'), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(PrismSegmented<LeaderboardTab>), findsOneWidget);
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

  testWidgets('switching tabs sends the event and tracks the view', (tester) async {
    await pumpPage(tester, loaded(tab: LeaderboardTab.friends, friends: const <LeaderboardEntry>[_me]));
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

  test('resetCaption counts down to Monday 00:00 UTC', () {
    expect(resetCaption(DateTime.utc(2026, 10, 17, 20)), 'Resets Monday · 1d 4h left');
  });
}
