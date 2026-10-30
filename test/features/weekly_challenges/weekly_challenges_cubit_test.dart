import 'dart:async';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/weekly_challenges/biz/weekly_challenges_cubit.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/features/weekly_challenges/domain/repositories/weekly_challenges_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_app_analytics.dart';

WeeklyChallenge challenge({ChallengeState state = ChallengeState.open}) => WeeklyChallenge(
  id: '2026-10-26',
  theme: 'Quiet oceans',
  state: state,
  opensAt: DateTime.utc(2020),
  closesAt: DateTime.utc(2100),
);
ChallengeEntry entry({bool voted = false, int count = 4, bool mine = false}) => ChallengeEntry(
  id: 'entry',
  wallId: 'wall',
  wallLogicalId: 'logical',
  creatorUid: 'creator',
  creatorName: 'Maya',
  thumbUrl: '',
  title: 'Ocean',
  voteCount: count,
  approvedAt: DateTime.utc(2026),
  voted: voted,
  mine: mine,
);

class Repository implements WeeklyChallengesRepository {
  ChallengeDetail detail = ChallengeDetail(challenge: challenge(), entries: [entry()], myEntryCount: 0);
  Future<ChallengeDetail>? pendingLoad;
  Future<List<WeeklyChallenge>>? pendingList;
  Future<({bool voted, int voteCount})>? pendingVote;
  bool fail = false;
  final List<bool> votes = [];
  final List<String> requestedIds = [];
  @override
  Future<List<WeeklyChallenge>> list({required bool past}) async =>
      pendingList ?? (past ? [challenge(state: ChallengeState.archived)] : [challenge()]);
  @override
  Future<ChallengeDetail> get(String id, ChallengeSort sort) async {
    requestedIds.add(id);
    if (fail) throw const ChallengeException(ChallengeError.missing);
    return pendingLoad ?? detail;
  }

  @override
  Future<({bool voted, int voteCount})> setVote(String challengeId, String entryId, {required bool vote}) async {
    votes.add(vote);
    return pendingVote ?? (voted: vote, voteCount: vote ? 5 : 4);
  }
}

void main() {
  late Repository repo;
  late WeeklyChallengesCubit cubit;
  setUp(() {
    repo = Repository();
    cubit = WeeklyChallengesCubit(repo);
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });
  tearDown(() async {
    await cubit.close();
    AnalyticsRuntime.reset();
  });
  for (final fail in [false, true]) {
    test('a previous challenge vote cannot change the replacement (failure=$fail)', () async {
      await cubit.load('2026-10-26');
      final pending = Completer<({bool voted, int voteCount})>();
      repo.pendingVote = pending.future;
      final voting = cubit.toggleVote(entry());
      final replacement = WeeklyChallenge(
        id: '2026-10-19',
        theme: 'Replacement',
        state: ChallengeState.open,
        opensAt: DateTime.utc(2020),
        closesAt: DateTime.utc(2100),
      );
      repo.detail = ChallengeDetail(challenge: replacement, entries: [entry(count: 12)], myEntryCount: 0);
      await cubit.load(replacement.id);
      expect(cubit.state.detail!.entries.single.voteCount, 12);
      if (fail) {
        pending.completeError(const ChallengeException(ChallengeError.missing));
      } else {
        pending.complete((voted: true, voteCount: 99));
      }
      await voting;
      expect(cubit.state.detail!.challenge.id, replacement.id);
      expect(cubit.state.detail!.entries.single.voteCount, 12);
      expect(cubit.state.error, isNull);
      expect(repo.requestedIds, ['2026-10-26', replacement.id]);
    });
  }
  test('replacement suppresses an older load and its viewed analytics', () async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final pending = Completer<ChallengeDetail>();
    repo.pendingLoad = pending.future;
    final old = cubit.load('2026-10-19');
    repo.pendingLoad = null;
    await cubit.load('2026-10-26');
    pending.complete(repo.detail);
    await old;
    expect(cubit.state.detail!.challenge.id, '2026-10-26');
    expect(
      analytics.events.where((e) => e.eventName == 'challenge_viewed').map((e) => e.toWireParameters()['challenge_id']),
      ['2026-10-26'],
    );
  });
  test('home refresh clears stale cards and does not restore them after failure', () async {
    await cubit.loadOpen(clock: () => DateTime.utc(2026));
    expect(cubit.state.current?.id, '2026-10-26');
    final pending = Completer<List<WeeklyChallenge>>();
    repo.pendingList = pending.future;
    final refresh = cubit.loadOpen(clock: () => DateTime.utc(2026));
    expect(cubit.state.current, isNull);
    pending.completeError(Exception('offline'));
    await refresh;
    expect(cubit.state.current, isNull);
    expect(cubit.state.failed, isTrue);
  });
  test('home loader ignores an older response after a newer refresh', () async {
    final pending = Completer<List<WeeklyChallenge>>();
    repo.pendingList = pending.future;
    final old = cubit.loadOpen(clock: () => DateTime.utc(2026));
    repo.pendingList = Future.value([]);
    await cubit.loadOpen(clock: () => DateTime.utc(2026));
    pending.complete([challenge()]);
    await old;
    expect(cubit.state.current, isNull);
  });
  test('a vote refused for a removed entry clears the stale wall even if refresh fails', () async {
    await cubit.load('2026-10-26');
    final pending = Completer<({bool voted, int voteCount})>();
    repo.pendingVote = pending.future;
    final vote = cubit.toggleVote(entry());
    repo.fail = true;
    pending.completeError(const ChallengeException(ChallengeError.missing));
    await vote;
    expect(cubit.state.detail, isNull);
    expect(cubit.state.failed, isTrue);
  });
  test('UTC bounds exclude a stale open flag and include the opening instant', () {
    final c = challenge();
    expect(c.isOpenAt(c.opensAt), isTrue);
    expect(c.isOpenAt(c.opensAt.subtract(const Duration(milliseconds: 1))), isFalse);
    expect(c.isOpenAt(c.closesAt), isFalse);
    expect(challenge(state: ChallengeState.votingClosed).isOpenAt(DateTime.utc(2026)), isFalse);
  });
  test('loads approved entries and past challenges', () async {
    await cubit.load('2026-10-26');
    expect(cubit.state.detail!.entries.single.creatorName, 'Maya');
    expect(cubit.state.past.single.state, ChallengeState.archived);
  });
  test('vote and unvote update immediately, then accept server counts', () async {
    await cubit.load('2026-10-26');
    final pending = Completer<({bool voted, int voteCount})>();
    repo.pendingVote = pending.future;
    final vote = cubit.toggleVote(entry());
    expect(cubit.state.detail!.entries.single.voted, isTrue);
    expect(cubit.state.detail!.entries.single.voteCount, 5);
    pending.complete((voted: true, voteCount: 9));
    await vote;
    expect(cubit.state.detail!.entries.single.voteCount, 9);
    repo.pendingVote = null;
    await cubit.toggleVote(cubit.state.detail!.entries.single);
    expect(cubit.state.detail!.entries.single.voted, isFalse);
    expect(repo.votes, [true, false]);
  });
  test('failed vote restores the previous count and exposes a typed error', () async {
    await cubit.load('2026-10-26');
    final pending = Completer<({bool voted, int voteCount})>();
    repo.pendingVote = pending.future;
    final vote = cubit.toggleVote(entry());
    pending.completeError(const ChallengeException(ChallengeError.dailyLimit));
    await vote;
    expect(cubit.state.detail!.entries.single.voteCount, 4);
    expect(cubit.state.detail!.entries.single.voted, isFalse);
    expect(cubit.state.error, ChallengeError.dailyLimit);
  });
  test('refresh never keeps withdrawn rows and ignores an older response', () async {
    await cubit.load('2026-10-26');
    final old = Completer<ChallengeDetail>();
    repo.pendingLoad = old.future;
    final first = cubit.load('2026-10-26');
    expect(cubit.state.detail, isNull);
    repo.pendingLoad = null;
    repo.detail = ChallengeDetail(challenge: challenge(), entries: [], myEntryCount: 1);
    await cubit.load('2026-10-26');
    old.complete(ChallengeDetail(challenge: challenge(), entries: [entry()], myEntryCount: 0));
    await first;
    expect(cubit.state.detail!.entries, isEmpty);
    repo.fail = true;
    await cubit.load('2026-10-26');
    expect(cubit.state.detail, isNull);
    expect(cubit.state.error, ChallengeError.missing);
  });
  test('refresh preserves a vote finishing after its request started without resurrecting absent rows', () async {
    await cubit.load('2026-10-26');
    final pendingVote = Completer<({bool voted, int voteCount})>();
    repo.pendingVote = pendingVote.future;
    final voting = cubit.toggleVote(entry());
    final pendingLoad = Completer<ChallengeDetail>();
    repo.pendingLoad = pendingLoad.future;
    final loading = cubit.load('2026-10-26');
    pendingVote.complete((voted: true, voteCount: 8));
    await voting;
    pendingLoad.complete(repo.detail);
    await loading;
    expect(cubit.state.detail!.entries.single.voteCount, 8);
    expect(cubit.state.detail!.entries.single.voted, isTrue);
  });
  test('own entries and closed challenges cannot vote', () async {
    repo.detail = ChallengeDetail(challenge: challenge(), entries: [entry(mine: true)], myEntryCount: 1);
    await cubit.load('2026-10-26');
    await cubit.toggleVote(entry());
    expect(repo.votes, isEmpty);
    repo.detail = ChallengeDetail(
      challenge: challenge(state: ChallengeState.votingClosed),
      entries: [entry()],
      myEntryCount: 0,
    );
    await cubit.load('2026-10-26');
    await cubit.toggleVote(entry());
    expect(repo.votes, isEmpty);
  });
}
