@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/leaderboard/biz/bloc/leaderboard_bloc.j.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/views/pages/leaderboard_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_app_analytics.dart';
import 'qa_harness.dart';

class _MockLeaderboardBloc extends MockBloc<LeaderboardEvent, LeaderboardState> implements LeaderboardBloc {}

const LeaderboardEntry _me = LeaderboardEntry(
  uid: 'me',
  name: 'Alex',
  username: 'alex',
  photo: '',
  xp: 180,
  rank: 'silver',
  isMe: true,
);

void main() {
  setUpAll(() async {
    registerFallbackValue(ProfileRoute());
    if (qaRender) await loadFonts();
  });

  Future<void> pumpLeaderboard(QaShot shot, LeaderboardTab tab, {double textScale = 1}) async {
    final _MockLeaderboardBloc bloc = _MockLeaderboardBloc();
    whenListen(
      bloc,
      const Stream<LeaderboardState>.empty(),
      initialState: LeaderboardState.initial().copyWith(
        tab: tab,
        friendsStatus: LoadStatus.success,
        globalStatus: LoadStatus.success,
        friends: const <LeaderboardEntry>[_me],
        global: const <LeaderboardEntry>[
          LeaderboardEntry(uid: 'ana', name: 'Ana', username: 'ana', photo: '', xp: 1240, rank: 'gold'),
          LeaderboardEntry(uid: 'sam', name: 'Sam', username: 'sam', photo: '', xp: 420, rank: 'prism'),
          _me,
        ],
      ),
    );
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    await shot.pump(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: BlocProvider<LeaderboardBloc>.value(value: bloc, child: const LeaderboardPage()),
      ),
    );
  }

  qaScreen('leaderboard_following_cold_start', (shot) async {
    await pumpLeaderboard(shot, LeaderboardTab.friends);
    await shot.save('leaderboard_following_cold_start');
  });

  qaScreen('leaderboard_global', (shot) async {
    await pumpLeaderboard(shot, LeaderboardTab.global);
    await shot.save('leaderboard_global');
  });

  qaScreen('leaderboard_scoring', (shot) async {
    await pumpLeaderboard(shot, LeaderboardTab.global);
    await shot.tester.tap(find.byTooltip('How leaderboard scoring works'));
    await shot.settle();
    await shot.save('leaderboard_scoring');
    await shot.tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -600));
    await shot.settle();
    await shot.save('leaderboard_scoring_bottom');
  });

  qaScreen('leaderboard_large_text', (shot) async {
    await pumpLeaderboard(shot, LeaderboardTab.friends, textScale: 2);
    await shot.save('leaderboard_large_text');
  });
}
