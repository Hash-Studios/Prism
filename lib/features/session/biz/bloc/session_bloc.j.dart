import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/session/domain/usecases/session_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'session_event.j.dart';
part 'session_state.j.dart';
part 'session_bloc.j.freezed.dart';

@injectable
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(
    this._getSessionUseCase,
    this._refreshPremiumUseCase,
    this._signOutUseCase, {
    SessionRepository? sessionRepository,
  }) : _sessionRepository = sessionRepository ?? getIt<SessionRepository>(),
       super(SessionState.initial()) {
    on<_Started>(_onStarted);
    on<_PremiumRefreshRequested>(_onPremiumRefreshRequested);
    on<_SignOutRequested>(_onSignOutRequested);
    _bindCurrentUserStream();
  }

  final GetSessionUseCase _getSessionUseCase;
  final RefreshPremiumUseCase _refreshPremiumUseCase;
  final SignOutUseCase _signOutUseCase;
  final SessionRepository _sessionRepository;
  StreamSubscription<dynamic>? _currentUserSubscription;
  Timer? _startedDebounce;

  static const Duration _startedDebounceDelay = Duration(milliseconds: 400);

  void _bindCurrentUserStream() {
    _currentUserSubscription?.cancel();
    _currentUserSubscription = _sessionRepository.watchCurrentUser().skip(1).listen((_) {
      _startedDebounce?.cancel();
      _startedDebounce = Timer(_startedDebounceDelay, () {
        if (!isClosed) {
          add(const SessionEvent.started());
        }
      });
    });
  }

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

  @override
  Future<void> close() async {
    _startedDebounce?.cancel();
    await _currentUserSubscription?.cancel();
    return super.close();
  }
}
