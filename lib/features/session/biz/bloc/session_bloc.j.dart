import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/usecases/session_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'session_event.j.dart';
part 'session_state.j.dart';
part 'session_bloc.j.freezed.dart';

@injectable
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(this._getSessionUseCase, this._refreshPremiumUseCase, this._signOutUseCase)
      : super(SessionState.initial()) {
    on<_Started>(_onStarted);
    on<_PremiumRefreshRequested>(_onPremiumRefreshRequested);
    on<_SignOutRequested>(_onSignOutRequested);
  }

  final GetSessionUseCase _getSessionUseCase;
  final RefreshPremiumUseCase _refreshPremiumUseCase;
  final SignOutUseCase _signOutUseCase;

  Future<void> _onStarted(_Started event, Emitter<SessionState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _getSessionUseCase(const NoParams());

    result.fold(
      onSuccess: (session) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.idle, session: session, failure: null),
      ),
      onFailure: (failure) =>
          emit(state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onPremiumRefreshRequested(_PremiumRefreshRequested event, Emitter<SessionState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _refreshPremiumUseCase(const NoParams());

    result.fold(
      onSuccess: (session) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, session: session, failure: null),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onSignOutRequested(_SignOutRequested event, Emitter<SessionState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _signOutUseCase(const NoParams());

    result.fold(
      onSuccess: (session) => emit(
        state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, session: session, failure: null),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }
}
