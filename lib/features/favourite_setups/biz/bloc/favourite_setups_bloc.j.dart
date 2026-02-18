import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';
import 'package:Prism/features/favourite_setups/domain/usecases/favourite_setups_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'favourite_setups_event.j.dart';
part 'favourite_setups_state.j.dart';
part 'favourite_setups_bloc.j.freezed.dart';

@injectable
class FavouriteSetupsBloc extends Bloc<FavouriteSetupsEvent, FavouriteSetupsState> {
  FavouriteSetupsBloc(
    this._fetchFavouriteSetupsUseCase,
    this._toggleFavouriteSetupUseCase,
    this._removeFavouriteSetupUseCase,
    this._clearFavouriteSetupsUseCase,
  ) : super(FavouriteSetupsState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_ToggleRequested>(_onToggleRequested);
    on<_RemoveRequested>(_onRemoveRequested);
    on<_ClearRequested>(_onClearRequested);
  }

  final FetchFavouriteSetupsUseCase _fetchFavouriteSetupsUseCase;
  final ToggleFavouriteSetupUseCase _toggleFavouriteSetupUseCase;
  final RemoveFavouriteSetupUseCase _removeFavouriteSetupUseCase;
  final ClearFavouriteSetupsUseCase _clearFavouriteSetupsUseCase;

  Future<void> _onStarted(_Started event, Emitter<FavouriteSetupsState> emit) async {
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        actionStatus: ActionStatus.inProgress,
        userId: event.userId,
        failure: null,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<FavouriteSetupsState> emit) {
    emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress));
    return _fetch(emit);
  }

  Future<void> _fetch(Emitter<FavouriteSetupsState> emit) async {
    if (state.userId.isEmpty) {
      emit(
        state.copyWith(
          status: LoadStatus.failure,
          actionStatus: ActionStatus.failure,
          failure: const ValidationFailure('userId is required'),
        ),
      );
      return;
    }

    final result = await _fetchFavouriteSetupsUseCase(FetchFavouriteSetupsParams(userId: state.userId));

    result.fold(
      onSuccess: (items) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, items: items, failure: null),
      ),
      onFailure: (failure) =>
          emit(state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onToggleRequested(_ToggleRequested event, Emitter<FavouriteSetupsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _toggleFavouriteSetupUseCase(
      ToggleFavouriteSetupParams(userId: state.userId, setup: event.setup),
    );

    result.fold(
      onSuccess: (items) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, items: items, failure: null),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onRemoveRequested(_RemoveRequested event, Emitter<FavouriteSetupsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _removeFavouriteSetupUseCase(
      RemoveFavouriteSetupParams(userId: state.userId, setupId: event.setupId),
    );

    result.fold(
      onSuccess: (items) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, items: items, failure: null),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onClearRequested(_ClearRequested event, Emitter<FavouriteSetupsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _clearFavouriteSetupsUseCase(ClearFavouriteSetupsParams(userId: state.userId));

    result.fold(
      onSuccess: (items) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, items: items, failure: null),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }
}
