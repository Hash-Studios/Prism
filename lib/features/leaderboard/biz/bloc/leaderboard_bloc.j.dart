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
    final bool friends = tab == LeaderboardTab.friends;
    emit(
      friends
          ? state.copyWith(tab: tab, friendsStatus: LoadStatus.loading)
          : state.copyWith(tab: tab, globalStatus: LoadStatus.loading),
    );
    final Result<List<LeaderboardEntry>> result = friends
        ? await _repository.fetchFriends(app_state.prismUser.following, isoWeekKey(DateTime.now().toUtc()))
        : await _repository.fetchGlobal();
    result.fold(
      onSuccess: (entries) => emit(
        friends
            ? state.copyWith(friendsStatus: LoadStatus.success, friends: entries)
            : state.copyWith(globalStatus: LoadStatus.success, global: entries),
      ),
      onFailure: (_) => emit(
        friends ? state.copyWith(friendsStatus: LoadStatus.failure) : state.copyWith(globalStatus: LoadStatus.failure),
      ),
    );
  }
}
