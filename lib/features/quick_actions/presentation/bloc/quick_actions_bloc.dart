import 'dart:async';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/quick_actions/domain/entities/quick_action_entity.dart';
import 'package:Prism/features/quick_actions/domain/usecases/quick_actions_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'quick_actions_event.dart';
part 'quick_actions_state.dart';
part 'quick_actions_bloc.freezed.dart';

@injectable
class QuickActionsBloc extends Bloc<QuickActionsEvent, QuickActionsState> {
  QuickActionsBloc(
    this._initializeQuickActionsUseCase,
    this._setQuickActionShortcutsUseCase,
    this._observeQuickActionsUseCase,
  ) : super(QuickActionsState.initial()) {
    on<_Started>(_onStarted);
    on<_ShortcutsSetupRequested>(_onShortcutsSetupRequested);
    on<_ActionReceived>(_onActionReceived);
    on<_HistoryCleared>(_onHistoryCleared);
  }

  final InitializeQuickActionsUseCase _initializeQuickActionsUseCase;
  final SetQuickActionShortcutsUseCase _setQuickActionShortcutsUseCase;
  final ObserveQuickActionsUseCase _observeQuickActionsUseCase;
  StreamSubscription<QuickActionEntity>? _subscription;

  Future<void> _onStarted(
      _Started event, Emitter<QuickActionsState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));

    final initResult = await _initializeQuickActionsUseCase(const NoParams());
    if (initResult.isFailure) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: initResult.failure,
      ));
      return;
    }

    if (event.setupShortcuts) {
      final shortcutResult =
          await _setQuickActionShortcutsUseCase(const NoParams());
      if (shortcutResult.isFailure) {
        emit(state.copyWith(
          status: LoadStatus.failure,
          actionStatus: ActionStatus.failure,
          failure: shortcutResult.failure,
        ));
        return;
      }
    }

    emit(state.copyWith(
      status: LoadStatus.success,
      actionStatus: ActionStatus.success,
      failure: null,
    ));

    await _subscription?.cancel();
    _subscription = _observeQuickActionsUseCase().listen((action) {
      add(QuickActionsEvent.actionReceived(action));
    });
  }

  Future<void> _onShortcutsSetupRequested(
    _ShortcutsSetupRequested event,
    Emitter<QuickActionsState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));

    final result = await _setQuickActionShortcutsUseCase(const NoParams());
    result.fold(
      onSuccess: (_) =>
          emit(state.copyWith(actionStatus: ActionStatus.success)),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  void _onActionReceived(
      _ActionReceived event, Emitter<QuickActionsState> emit) {
    emit(state.copyWith(
      actionStatus: ActionStatus.success,
      latestAction: event.action,
      history: <QuickActionEntity>[...state.history, event.action],
      failure: null,
    ));
  }

  void _onHistoryCleared(
      _HistoryCleared event, Emitter<QuickActionsState> emit) {
    emit(state.copyWith(history: const <QuickActionEntity>[]));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
