import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'trending_event.j.dart';
part 'trending_state.j.dart';
part 'trending_bloc.j.freezed.dart';

@injectable
class TrendingBloc extends Bloc<TrendingEvent, TrendingState> {
  TrendingBloc(this._fetchTrendingUseCase, this._userBlockRepository) : super(TrendingState.initial()) {
    on<_Started>((event, emit) {
      CoinsService.instance.reportQuestEvent(QuestEvent.viewTrending);
      return _load(TrendingRange.week, emit);
    });
    on<_RangeSelected>(_onRangeSelected);
    on<_RefreshRequested>((event, emit) => _load(state.range, emit));
    on<_BlockedCreatorsChanged>(_onBlockedCreatorsChanged);
    _blockedCreatorsSub = _userBlockRepository.watchBlockedCreatorEmails().listen(
      (blocked) => add(TrendingEvent.blockedCreatorsChanged(blocked: blocked)),
    );
  }

  final FetchTrendingUseCase _fetchTrendingUseCase;
  final UserBlockRepository _userBlockRepository;
  StreamSubscription<Set<String>>? _blockedCreatorsSub;
  Set<String> _blocked = const <String>{};
  final Map<TrendingRange, int> _latestRequestIds = <TrendingRange, int>{};

  /// Blocking a creator removes their walls from both lists at once, without waiting for the next load. Unblocking one
  /// loads the lists again, because their walls were dropped from the state.
  Future<void> _onBlockedCreatorsChanged(_BlockedCreatorsChanged event, Emitter<TrendingState> emit) async {
    final bool unblocked = _blocked.any((email) => !event.blocked.contains(email));
    _blocked = event.blocked;
    if (unblocked) {
      await Future.wait(
        TrendingRange.values
            .where((range) => state.section(range).status != LoadStatus.initial)
            .map((range) => _load(range, emit)),
      );
      return;
    }
    if (_blocked.isEmpty) return;
    for (final TrendingRange range in TrendingRange.values) {
      final TrendingSection section = state.section(range);
      final List<PrismWallpaper> visible = _withoutBlocked(section.walls);
      if (visible.length != section.walls.length) emit(state.withSection(range, section.copyWith(walls: visible)));
    }
  }

  List<PrismWallpaper> _withoutBlocked(List<PrismWallpaper> walls) => walls
      .where((wall) => !BlockedCreatorsFilter.hidesCreatorEmail(wall.core.authorEmail, _blocked))
      .toList(growable: false);

  @override
  Future<void> close() {
    unawaited(_blockedCreatorsSub?.cancel());
    return super.close();
  }

  Future<void> _onRangeSelected(_RangeSelected event, Emitter<TrendingState> emit) async {
    emit(state.copyWith(range: event.range));
    final LoadStatus status = state.section(event.range).status;
    if (status == LoadStatus.initial || status == LoadStatus.failure) {
      await _load(event.range, emit);
    }
  }

  /// Keeps the walls on screen while a refresh runs, and when it fails.
  Future<void> _load(TrendingRange range, Emitter<TrendingState> emit) async {
    final int requestId = (_latestRequestIds[range] ?? 0) + 1;
    _latestRequestIds[range] = requestId;
    emit(state.withSection(range, state.section(range).copyWith(status: LoadStatus.loading, failure: null)));
    final result = await _fetchTrendingUseCase(range);
    if (requestId != _latestRequestIds[range]) return;
    result.fold(
      onSuccess: (walls) => emit(
        state.withSection(
          range,
          state.section(range).copyWith(status: LoadStatus.success, walls: _withoutBlocked(walls)),
        ),
      ),
      onFailure: (failure) =>
          emit(state.withSection(range, state.section(range).copyWith(status: LoadStatus.failure, failure: failure))),
    );
  }
}
