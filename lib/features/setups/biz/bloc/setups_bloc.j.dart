import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/usecases/setups_usecases.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'setups_event.j.dart';
part 'setups_state.j.dart';
part 'setups_bloc.j.freezed.dart';

/// Dispatched when the blocked-creators stream emits a change, so the current
/// items can be re-filtered in place without a refetch. Hand-written (not a
/// case in the `@freezed` [SetupsEvent] union) since `SetupsEvent` declares no
/// abstract members beyond `Object`'s (freezed's `when`/`map` live in a
/// separate extension, unused by this bloc), so implementing it directly here
/// needs no `build_runner` regen.
// ignore: avoid_implementing_value_types
class _BlockedCreatorsChanged implements SetupsEvent {
  const _BlockedCreatorsChanged(this.blocked);

  final Set<String> blocked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _BlockedCreatorsChanged &&
          other.blocked.length == blocked.length &&
          other.blocked.containsAll(blocked));

  @override
  int get hashCode => Object.hashAllUnordered(blocked);
}

@injectable
class SetupsBloc extends Bloc<SetupsEvent, SetupsState> {
  SetupsBloc(this._fetchSetupsUseCase, this._userBlockRepository) : super(SetupsState.initial()) {
    on<_Started>(_onStarted);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
    on<_BlockedCreatorsChanged>(_onBlockedCreatorsChanged);
    // Blocking a creator removes their setups from the on-screen list instantly,
    // without waiting for the next fetch. skip(1) ignores the initial snapshot.
    _blockedCreatorsSub = _userBlockRepository
        .watchBlockedCreatorEmails()
        .skip(1)
        .listen((blocked) => add(_BlockedCreatorsChanged(blocked)));
  }

  final FetchSetupsUseCase _fetchSetupsUseCase;
  final UserBlockRepository _userBlockRepository;
  StreamSubscription<Set<String>>? _blockedCreatorsSub;

  void _onBlockedCreatorsChanged(_BlockedCreatorsChanged event, Emitter<SetupsState> emit) {
    if (event.blocked.isEmpty) {
      return;
    }
    final filtered = state.items
        .where((SetupEntity s) => !BlockedCreatorsFilter.hidesCreatorEmail(s.email, event.blocked))
        .toList(growable: false);
    if (filtered.length != state.items.length) {
      emit(state.copyWith(items: filtered));
    }
  }

  @override
  Future<void> close() {
    unawaited(_blockedCreatorsSub?.cancel());
    return super.close();
  }

  Future<void> _onStarted(_Started event, Emitter<SetupsState> emit) {
    return _load(refresh: true, emit: emit);
  }

  Future<void> _onFetchMoreRequested(_FetchMoreRequested event, Emitter<SetupsState> emit) async {
    if (state.isFetchingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(isFetchingMore: true, actionStatus: ActionStatus.inProgress));
    await _load(refresh: false, emit: emit);
  }

  Future<void> _load({required bool refresh, required Emitter<SetupsState> emit}) async {
    if (refresh) {
      emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress, failure: null));
    }

    final result = await _fetchSetupsUseCase(FetchSetupsParams(refresh: refresh));

    result.fold(
      onSuccess: (page) {
        final merged = refresh ? page.items : <SetupEntity>[...state.items, ...page.items];
        final uniqueById = <String, SetupEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            items: uniqueById,
            hasMore: page.hasMore,
            nextCursor: page.nextCursor,
            isFetchingMore: false,
            failure: null,
          ),
        );
      },
      onFailure: (failure) => emit(
        state.copyWith(
          status: LoadStatus.failure,
          actionStatus: ActionStatus.failure,
          isFetchingMore: false,
          failure: failure,
        ),
      ),
    );
  }
}
