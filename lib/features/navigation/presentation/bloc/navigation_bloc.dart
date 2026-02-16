import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/navigation/domain/entities/navigation_stack_entity.dart';
import 'package:Prism/features/navigation/domain/usecases/navigation_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'navigation_event.dart';
part 'navigation_state.dart';
part 'navigation_bloc.freezed.dart';

@injectable
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  NavigationBloc(
    this._getNavigationStackUseCase,
    this._pushRouteUseCase,
    this._popRouteUseCase,
    this._resetNavigationUseCase,
    this._replaceNavigationStackUseCase,
  ) : super(NavigationState.initial()) {
    on<_Started>(_onStarted);
    on<_RoutePushed>(_onRoutePushed);
    on<_RoutePopped>(_onRoutePopped);
    on<_ResetRequested>(_onResetRequested);
    on<_StackReplaced>(_onStackReplaced);
  }

  final GetNavigationStackUseCase _getNavigationStackUseCase;
  final PushRouteUseCase _pushRouteUseCase;
  final PopRouteUseCase _popRouteUseCase;
  final ResetNavigationUseCase _resetNavigationUseCase;
  final ReplaceNavigationStackUseCase _replaceNavigationStackUseCase;

  Future<void> _onStarted(_Started event, Emitter<NavigationState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));

    final result = await _getNavigationStackUseCase(const NoParams());
    _emitResult(emit, result);
  }

  Future<void> _onRoutePushed(
    _RoutePushed event,
    Emitter<NavigationState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress));
    final result =
        await _pushRouteUseCase(PushRouteParams(routeName: event.routeName));
    _emitResult(emit, result);
  }

  Future<void> _onRoutePopped(
    _RoutePopped event,
    Emitter<NavigationState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress));
    final result = await _popRouteUseCase(const NoParams());
    _emitResult(emit, result);
  }

  Future<void> _onResetRequested(
    _ResetRequested event,
    Emitter<NavigationState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress));
    final result = await _resetNavigationUseCase(
      ResetNavigationParams(initialRoute: event.initialRoute),
    );
    _emitResult(emit, result);
  }

  Future<void> _onStackReplaced(
    _StackReplaced event,
    Emitter<NavigationState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress));
    final result = await _replaceNavigationStackUseCase(
        ReplaceNavigationStackParams(stack: event.stack));
    _emitResult(emit, result);
  }

  void _emitResult(
    Emitter<NavigationState> emit,
    Result<NavigationStackEntity> result,
  ) {
    result.fold(
      onSuccess: (NavigationStackEntity stack) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        stack: stack.stack,
        currentRoute: stack.current,
        canPop: stack.canPop,
        failure: null,
      )),
      onFailure: (Failure failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }
}
