import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
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
    on<_Started>(_onStarted);
    on<_RefreshRequested>((event, emit) => _load(emit));
    on<_BlockedCreatorsChanged>(_onBlockedCreatorsChanged);
    _blockedCreatorsSub = _userBlockRepository.watchBlockedCreatorEmails().listen(
      (blocked) => add(TrendingEvent.blockedCreatorsChanged(blocked: blocked)),
    );
  }

  final FetchTrendingUseCase _fetchTrendingUseCase;
  final UserBlockRepository _userBlockRepository;
  StreamSubscription<Set<String>>? _blockedCreatorsSub;
  Set<String> _blocked = const <String>{};
  int _latestRequestId = 0;

  /// Blocking a creator removes their walls at once, without waiting for the next load. Unblocking one loads the list
  /// again, because their walls were dropped from the state.
  Future<void> _onBlockedCreatorsChanged(_BlockedCreatorsChanged event, Emitter<TrendingState> emit) async {
    final bool unblocked = _blocked.any((email) => !event.blocked.contains(email));
    _blocked = event.blocked;
    if (unblocked) {
      if (state.status != LoadStatus.initial) await _load(emit);
      return;
    }
    if (_blocked.isEmpty) return;
    final List<PrismWallpaper> visible = _withoutBlocked(state.walls);
    if (visible.length != state.walls.length) emit(state.copyWith(walls: visible));
  }

  List<PrismWallpaper> _withoutBlocked(List<PrismWallpaper> walls) => walls
      .where((wall) => !BlockedCreatorsFilter.hidesCreatorEmail(wall.core.authorEmail, _blocked))
      .toList(growable: false);

  @override
  Future<void> close() {
    unawaited(_blockedCreatorsSub?.cancel());
    return super.close();
  }

  /// Paints the saved walls at once when none are on screen, then loads the fresh list behind them.
  Future<void> _onStarted(_Started event, Emitter<TrendingState> emit) async {
    final int requestId = _latestRequestId;
    final Future<Result<List<PrismWallpaper>>> fresh = _fetchTrendingUseCase(const NoParams())..ignore();
    if (state.walls.isEmpty) {
      List<PrismWallpaper> cached = const <PrismWallpaper>[];
      try {
        cached = _withoutBlocked(await _fetchTrendingUseCase.readCached());
      } catch (_) {}
      if (emit.isDone || requestId != _latestRequestId) return;
      if (cached.isNotEmpty && state.walls.isEmpty) {
        emit(state.copyWith(status: LoadStatus.success, walls: cached));
      }
    }
    return _load(emit, pending: fresh);
  }

  /// Keeps the walls on screen while a refresh runs, and when it fails. [pending] is a fetch already under way.
  Future<void> _load(Emitter<TrendingState> emit, {Future<Result<List<PrismWallpaper>>>? pending}) async {
    final int requestId = ++_latestRequestId;
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await (pending ?? _fetchTrendingUseCase(const NoParams()));
    if (requestId != _latestRequestId) return;
    result.fold(
      onSuccess: (walls) => emit(state.copyWith(status: LoadStatus.success, walls: _withoutBlocked(walls))),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
  }
}
