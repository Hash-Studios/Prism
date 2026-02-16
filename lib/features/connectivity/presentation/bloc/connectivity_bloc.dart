import 'dart:async';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/connectivity/domain/entities/connectivity_entity.dart';
import 'package:Prism/features/connectivity/domain/usecases/connectivity_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'connectivity_event.dart';
part 'connectivity_state.dart';
part 'connectivity_bloc.freezed.dart';

@injectable
class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  ConnectivityBloc(
    this._checkConnectionUseCase,
    this._watchConnectionUseCase,
  ) : super(ConnectivityState.initial()) {
    on<_Started>(_onStarted);
    on<_StatusChanged>(_onStatusChanged);
    on<_RecheckRequested>(_onRecheckRequested);
  }

  final CheckConnectionUseCase _checkConnectionUseCase;
  final WatchConnectionUseCase _watchConnectionUseCase;
  StreamSubscription<ConnectivityEntity>? _subscription;

  Future<void> _onStarted(
      _Started event, Emitter<ConnectivityState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));

    final result = await _checkConnectionUseCase(const NoParams());
    result.fold(
      onSuccess: (connectivity) {
        emit(state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          connectivity: connectivity,
          failure: null,
        ));
      },
      onFailure: (failure) {
        emit(state.copyWith(
          status: LoadStatus.failure,
          actionStatus: ActionStatus.failure,
          failure: failure,
        ));
      },
    );

    await _subscription?.cancel();
    _subscription = _watchConnectionUseCase().listen((connectivity) {
      add(ConnectivityEvent.statusChanged(connectivity));
    });
  }

  void _onStatusChanged(_StatusChanged event, Emitter<ConnectivityState> emit) {
    emit(state.copyWith(
      status: LoadStatus.success,
      actionStatus: ActionStatus.success,
      connectivity: event.connectivity,
      failure: null,
    ));
  }

  Future<void> _onRecheckRequested(
    _RecheckRequested event,
    Emitter<ConnectivityState> emit,
  ) {
    add(const ConnectivityEvent.started());
    return Future<void>.value();
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
