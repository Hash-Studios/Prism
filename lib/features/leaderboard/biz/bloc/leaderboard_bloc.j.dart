import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:Prism/features/leaderboard/domain/week_key.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'leaderboard_event.j.dart';
part 'leaderboard_state.j.dart';
part 'leaderboard_bloc.j.freezed.dart';

@injectable
class LeaderboardBloc extends Bloc<LeaderboardEvent, LeaderboardState> {
  LeaderboardBloc(this._repository) : super(LeaderboardState.initial()) {
    on<_Started>((_, emit) => _load(LeaderboardTab.friends, emit));
    on<_TabChanged>(_onTabChanged);
    on<_Refreshed>((_, emit) => _load(state.tab, emit));
  }

  final LeaderboardRepository _repository;

  Future<void> _onTabChanged(_TabChanged event, Emitter<LeaderboardState> emit) async {
    emit(state.copyWith(tab: event.tab));
    final LoadStatus status = state.status;
    if (status == LoadStatus.initial || status == LoadStatus.failure) {
      await _load(event.tab, emit);
    }
  }

  Future<void> _load(LeaderboardTab tab, Emitter<LeaderboardState> emit) async {
    if (tab == LeaderboardTab.global) {
      emit(state.copyWith(tab: tab));
      return _loadGlobal(emit);
    }
    emit(state.copyWith(tab: tab, friendsStatus: LoadStatus.loading));
    final Result<List<LeaderboardEntry>> result = await _repository.fetchFriends(
      app_state.prismUser.following,
      isoWeekKey(DateTime.now().toUtc()),
    );
    result.fold(
      onSuccess: (entries) => emit(state.copyWith(friendsStatus: LoadStatus.success, friends: entries)),
      onFailure: (_) => emit(state.copyWith(friendsStatus: LoadStatus.failure)),
    );
    // A short Following list shows the global top 5 under it. Load it once, in place: the tab does not change.
    final LoadStatus global = state.globalStatus;
    if (state.friendsStatus == LoadStatus.success &&
        state.friends.length < shortFriendsList &&
        global != LoadStatus.success &&
        global != LoadStatus.loading) {
      await _loadGlobal(emit);
    }
  }

  /// Loads the global board. It changes only [LeaderboardState.global] and [LeaderboardState.globalStatus].
  Future<void> _loadGlobal(Emitter<LeaderboardState> emit) async {
    if (state.globalStatus == LoadStatus.loading) return;
    emit(state.copyWith(globalStatus: LoadStatus.loading));
    final Result<List<LeaderboardEntry>> result = await _repository.fetchGlobal();
    result.fold(
      onSuccess: (entries) => emit(state.copyWith(globalStatus: LoadStatus.success, global: entries)),
      onFailure: (_) => emit(state.copyWith(globalStatus: LoadStatus.failure)),
    );
  }
}

/// Fewer Following rows than this show the follow tip and the global top list under them.
const int shortFriendsList = 5;
