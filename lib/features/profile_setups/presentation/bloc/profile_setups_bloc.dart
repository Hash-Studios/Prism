import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/profile_setups/domain/entities/profile_setup_entity.dart';
import 'package:Prism/features/profile_setups/domain/usecases/profile_setups_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'profile_setups_event.dart';
part 'profile_setups_state.dart';
part 'profile_setups_bloc.freezed.dart';

@injectable
class ProfileSetupsBloc extends Bloc<ProfileSetupsEvent, ProfileSetupsState> {
  ProfileSetupsBloc(this._fetchProfileSetupsUseCase) : super(ProfileSetupsState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
  }

  final FetchProfileSetupsUseCase _fetchProfileSetupsUseCase;

  Future<void> _onStarted(
    _Started event,
    Emitter<ProfileSetupsState> emit,
  ) async {
    emit(state.copyWith(email: event.email));
    await _load(refresh: true, emit: emit);
  }

  Future<void> _onRefreshRequested(
    _RefreshRequested event,
    Emitter<ProfileSetupsState> emit,
  ) {
    return _load(refresh: true, emit: emit);
  }

  Future<void> _onFetchMoreRequested(
    _FetchMoreRequested event,
    Emitter<ProfileSetupsState> emit,
  ) async {
    if (state.isFetchingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(isFetchingMore: true, actionStatus: ActionStatus.inProgress));
    await _load(refresh: false, emit: emit);
  }

  Future<void> _load({required bool refresh, required Emitter<ProfileSetupsState> emit}) async {
    if (state.email.isEmpty) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: const ValidationFailure('email is required'),
      ));
      return;
    }

    if (refresh) {
      emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress));
    }

    final result = await _fetchProfileSetupsUseCase(
      FetchProfileSetupsParams(email: state.email, refresh: refresh),
    );

    result.fold(
      onSuccess: (page) {
        final merged = refresh ? page.items : <ProfileSetupEntity>[...state.items, ...page.items];
        final deduped = <String, ProfileSetupEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: deduped,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          isFetchingMore: false,
          failure: null,
        ));
      },
      onFailure: (failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        isFetchingMore: false,
        failure: failure,
      )),
    );
  }
}
