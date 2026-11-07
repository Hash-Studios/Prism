import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/leaderboard/biz/bloc/leaderboard_bloc.j.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements LeaderboardRepository {}

const LeaderboardEntry _ana = LeaderboardEntry(
  uid: 'a',
  name: 'Ana',
  username: 'ana',
  photo: '',
  xp: 10,
  rank: 'bronze',
);

void main() {
  late _MockRepository repository;

  setUp(() {
    repository = _MockRepository();
    when(() => repository.fetchFriends(any(), any())).thenAnswer((_) async => Result.success(const [_ana]));
    when(() => repository.fetchGlobal()).thenAnswer((_) async => Result.success(const <LeaderboardEntry>[]));
  });

  test('refresh joins the automatic global load instead of fetching twice', () async {
    final pending = Completer<Result<List<LeaderboardEntry>>>();
    when(() => repository.fetchGlobal()).thenAnswer((_) => pending.future);
    final bloc = LeaderboardBloc(repository);
    bloc.add(const LeaderboardEvent.started());
    await bloc.stream.firstWhere((state) => state.globalStatus == LoadStatus.loading);
    bloc.add(const LeaderboardEvent.tabChanged(LeaderboardTab.global));
    await bloc.stream.firstWhere((state) => state.tab == LeaderboardTab.global);
    bloc.add(const LeaderboardEvent.refreshed());
    await Future<void>.delayed(Duration.zero);
    pending.complete(Result.success(const [_ana]));
    await bloc.stream.firstWhere((state) => state.globalStatus == LoadStatus.success);
    expect(bloc.state.tab, LeaderboardTab.global);
    expect(bloc.state.global, const [_ana]);
    await bloc.close();
    verify(() => repository.fetchGlobal()).called(1);
  });

  blocTest<LeaderboardBloc, LeaderboardState>(
    'started loads the friends tab',
    build: () => LeaderboardBloc(repository),
    act: (bloc) => bloc.add(const LeaderboardEvent.started()),
    expect: () => <Matcher>[
      isA<LeaderboardState>().having((s) => s.friendsStatus, 'friendsStatus', LoadStatus.loading),
      isA<LeaderboardState>().having((s) => s.friendsStatus, 'friendsStatus', LoadStatus.success).having(
        (s) => s.friends,
        'friends',
        const [_ana],
      ),
      // One friend is a short list, so the global top list loads under it.
      isA<LeaderboardState>().having((s) => s.globalStatus, 'globalStatus', LoadStatus.loading),
      isA<LeaderboardState>().having((s) => s.globalStatus, 'globalStatus', LoadStatus.success),
    ],
  );

  blocTest<LeaderboardBloc, LeaderboardState>(
    'a short following list loads global in place and keeps the selected tab',
    build: () => LeaderboardBloc(repository),
    setUp: () {
      when(() => repository.fetchGlobal()).thenAnswer((_) async => Result.success(const [_ana]));
    },
    act: (bloc) => bloc.add(const LeaderboardEvent.started()),
    verify: (bloc) {
      verify(() => repository.fetchGlobal()).called(1);
      expect(bloc.state.tab, LeaderboardTab.friends);
      expect(bloc.state.globalStatus, LoadStatus.success);
      expect(bloc.state.global, const [_ana]);
      expect(bloc.state.friends, const [_ana]);
    },
  );

  blocTest<LeaderboardBloc, LeaderboardState>(
    'the in-place global load does not undo a tab change made while it runs',
    build: () => LeaderboardBloc(repository),
    setUp: () {
      when(() => repository.fetchGlobal()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return Result.success(const [_ana]);
      });
    },
    act: (bloc) async {
      bloc.add(const LeaderboardEvent.started());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LeaderboardEvent.tabChanged(LeaderboardTab.global));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    },
    verify: (bloc) {
      // The tab change saw a load in flight, so it did not start a second one.
      verify(() => repository.fetchGlobal()).called(1);
      expect(bloc.state.tab, LeaderboardTab.global);
      expect(bloc.state.globalStatus, LoadStatus.success);
      expect(bloc.state.global, const [_ana]);
    },
  );

  blocTest<LeaderboardBloc, LeaderboardState>(
    'five or more following rows do not load global',
    build: () => LeaderboardBloc(repository),
    setUp: () {
      when(
        () => repository.fetchFriends(any(), any()),
      ).thenAnswer((_) async => Result.success(List<LeaderboardEntry>.filled(5, _ana)));
    },
    act: (bloc) => bloc.add(const LeaderboardEvent.started()),
    verify: (bloc) {
      verifyNever(() => repository.fetchGlobal());
      expect(bloc.state.globalStatus, LoadStatus.initial);
    },
  );

  blocTest<LeaderboardBloc, LeaderboardState>(
    'tabChanged loads the global tab once',
    build: () => LeaderboardBloc(repository),
    act: (bloc) async {
      bloc.add(const LeaderboardEvent.tabChanged(LeaderboardTab.global));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LeaderboardEvent.tabChanged(LeaderboardTab.friends));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LeaderboardEvent.tabChanged(LeaderboardTab.global));
    },
    verify: (bloc) {
      verify(() => repository.fetchGlobal()).called(1);
      expect(bloc.state.tab, LeaderboardTab.global);
      expect(bloc.state.globalStatus, LoadStatus.success);
    },
  );

  blocTest<LeaderboardBloc, LeaderboardState>(
    'a failed load can be retried by refreshing',
    build: () => LeaderboardBloc(repository),
    setUp: () {
      when(() => repository.fetchFriends(any(), any())).thenAnswer((_) async => Result.error(const ServerFailure('x')));
    },
    act: (bloc) async {
      bloc.add(const LeaderboardEvent.started());
      await Future<void>.delayed(Duration.zero);
      when(() => repository.fetchFriends(any(), any())).thenAnswer((_) async => Result.success(const [_ana]));
      bloc.add(const LeaderboardEvent.refreshed());
    },
    verify: (bloc) => expect(bloc.state.friendsStatus, LoadStatus.success),
  );
}
