import 'dart:async';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/features/weekly_challenges/domain/repositories/weekly_challenges_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

class WeeklyChallengesState {
  const WeeklyChallengesState({
    this.detail,
    this.current,
    this.past = const [],
    this.loading = true,
    this.failed = false,
    this.error,
    this.sort = ChallengeSort.top,
  });
  final ChallengeDetail? detail;
  final WeeklyChallenge? current;
  final List<WeeklyChallenge> past;
  final bool loading;
  final bool failed;
  final ChallengeError? error;
  final ChallengeSort sort;
}

@injectable
class WeeklyChallengesCubit extends Cubit<WeeklyChallengesState> {
  WeeklyChallengesCubit(this._repository) : super(const WeeklyChallengesState());
  final WeeklyChallengesRepository _repository;
  int _load = 0;
  int _voteVersion = 0;
  String? _challengeId;
  int _challengeVersion = 0;
  final Map<String, int> _versions = {};
  final Set<String> _pending = {};
  final Map<String, ({bool voted, int count})> _votes = {};
  String? _viewed;
  Timer? _closeTimer;

  Future<void> loadOpen({DateTime Function()? clock}) async {
    final version = ++_load;
    _closeTimer?.cancel();
    emit(const WeeklyChallengesState());
    try {
      final rows = await _repository.list(past: false);
      if (isClosed || version != _load) return;
      final now = (clock?.call() ?? DateTime.now()).toUtc();
      final current = rows.where((row) => row.isOpenAt(now)).firstOrNull;
      emit(WeeklyChallengesState(current: current, loading: false));
      if (current != null) {
        _closeTimer = Timer(current.closesAt.difference(now), () {
          if (!isClosed && version == _load) emit(const WeeklyChallengesState(loading: false));
        });
      }
    } catch (_) {
      if (!isClosed && version == _load) emit(const WeeklyChallengesState(loading: false, failed: true));
    }
  }

  @override
  Future<void> close() {
    _closeTimer?.cancel();
    return super.close();
  }

  Future<void> load(String id, {ChallengeSort? sort}) async {
    final changed = _challengeId != id;
    if (changed) {
      _challengeId = id;
      _challengeVersion++;
      _pending.clear();
      _votes.clear();
      _versions.clear();
    }
    _closeTimer?.cancel();
    final int version = ++_load;
    final int votes = _voteVersion;
    final ChallengeSort selected = sort ?? (changed ? ChallengeSort.top : state.sort);
    emit(WeeklyChallengesState(sort: selected));
    try {
      final detail = await _repository.get(id, selected);
      final past = await _repository.list(past: true);
      if (isClosed || version != _load) return;
      final entries = detail.entries
          .map((entry) {
            final recent = _votes[entry.id];
            return recent != null && (_pending.contains(entry.id) || (_versions[entry.id] ?? 0) > votes)
                ? entry.copyWith(voted: recent.voted, voteCount: recent.count)
                : entry;
          })
          .toList(growable: false);
      emit(
        WeeklyChallengesState(
          detail: ChallengeDetail(challenge: detail.challenge, entries: entries, myEntryCount: detail.myEntryCount),
          past: past,
          loading: false,
          sort: selected,
        ),
      );
      if (_viewed != id) {
        _viewed = id;
        analytics.track(ChallengeViewedEvent(challengeId: id));
      }
    } on ChallengeException catch (e) {
      if (!isClosed && version == _load) {
        emit(WeeklyChallengesState(loading: false, failed: true, error: e.error, sort: selected));
      }
    } catch (_) {
      if (!isClosed && version == _load) {
        emit(WeeklyChallengesState(loading: false, failed: true, error: ChallengeError.unknown, sort: selected));
      }
    }
  }

  Future<void> toggleVote(ChallengeEntry entry) async {
    final detail = state.detail;
    final current = detail?.entries.where((row) => row.id == entry.id).firstOrNull;
    if (detail == null ||
        current == null ||
        current.mine ||
        !detail.challenge.isOpenAt(DateTime.now().toUtc()) ||
        !_pending.add(entry.id)) {
      return;
    }
    final challengeVersion = _challengeVersion;
    final bool vote = !current.voted;
    _replace(current.id, vote, current.voteCount + (vote ? 1 : -1));
    try {
      final result = await _repository.setVote(detail.challenge.id, current.id, vote: vote);
      if (!isClosed && challengeVersion == _challengeVersion) {
        _replace(current.id, result.voted, result.voteCount);
      }
      analytics.track(
        result.voted
            ? ChallengeVotedEvent(challengeId: detail.challenge.id)
            : ChallengeUnvotedEvent(challengeId: detail.challenge.id),
      );
    } catch (e) {
      if (isClosed || challengeVersion != _challengeVersion) return;
      _replace(
        current.id,
        current.voted,
        current.voteCount,
        error: e is ChallengeException ? e.error : ChallengeError.unknown,
      );
      if (e is ChallengeException &&
          [ChallengeError.missing, ChallengeError.closed, ChallengeError.signedOut].contains(e.error)) {
        await load(detail.challenge.id);
      }
    } finally {
      if (challengeVersion == _challengeVersion) _pending.remove(current.id);
    }
  }

  void _replace(String id, bool voted, int count, {ChallengeError? error}) {
    if (isClosed) return;
    _versions[id] = ++_voteVersion;
    _votes[id] = (voted: voted, count: count);
    final detail = state.detail;
    if (detail == null) return;
    emit(
      WeeklyChallengesState(
        detail: ChallengeDetail(
          challenge: detail.challenge,
          entries: detail.entries
              .map((entry) => entry.id == id ? entry.copyWith(voted: voted, voteCount: count) : entry)
              .toList(growable: false),
          myEntryCount: detail.myEntryCount,
        ),
        past: state.past,
        loading: state.loading,
        sort: state.sort,
        error: error,
      ),
    );
  }
}
