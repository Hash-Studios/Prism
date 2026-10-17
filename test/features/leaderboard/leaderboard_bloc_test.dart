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
    ],
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
