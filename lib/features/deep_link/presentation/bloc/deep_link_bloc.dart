import 'dart:async';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';
import 'package:Prism/features/deep_link/domain/usecases/deep_link_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'deep_link_event.dart';
part 'deep_link_state.dart';
part 'deep_link_bloc.freezed.dart';

@injectable
class DeepLinkBloc extends Bloc<DeepLinkEvent, DeepLinkState> {
  DeepLinkBloc(
    this._getInitialDeepLinkActionUseCase,
    this._observeDeepLinkActionsUseCase,
  ) : super(DeepLinkState.initial()) {
    on<_Started>(_onStarted);
    on<_ActionReceived>(_onActionReceived);
    on<_HistoryCleared>(_onHistoryCleared);
  }

  final GetInitialDeepLinkActionUseCase _getInitialDeepLinkActionUseCase;
  final ObserveDeepLinkActionsUseCase _observeDeepLinkActionsUseCase;
  StreamSubscription<DeepLinkActionEntity>? _subscription;

  Future<void> _onStarted(_Started event, Emitter<DeepLinkState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));

    final result = await _getInitialDeepLinkActionUseCase(const NoParams());
    result.fold(
      onSuccess: (action) {
        emit(state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          initialAction: action,
          latestAction: action,
          history: action == null ? const <DeepLinkActionEntity>[] : <DeepLinkActionEntity>[action],
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
    _subscription = _observeDeepLinkActionsUseCase().listen((action) {
      add(DeepLinkEvent.actionReceived(action));
    });
  }

  void _onActionReceived(_ActionReceived event, Emitter<DeepLinkState> emit) {
    emit(state.copyWith(
      status: LoadStatus.success,
      actionStatus: ActionStatus.success,
      latestAction: event.action,
      history: <DeepLinkActionEntity>[...state.history, event.action],
      failure: null,
    ));
  }

  void _onHistoryCleared(_HistoryCleared event, Emitter<DeepLinkState> emit) {
    emit(state.copyWith(history: const <DeepLinkActionEntity>[]));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
