import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/usecases/notifications_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'in_app_notifications_event.j.dart';
part 'in_app_notifications_state.j.dart';
part 'in_app_notifications_bloc.j.freezed.dart';

@injectable
class InAppNotificationsBloc extends Bloc<InAppNotificationsEvent, InAppNotificationsState> {
  InAppNotificationsBloc(
    this._fetchNotificationsUseCase,
    this._markNotificationAsReadUseCase,
    this._deleteNotificationUseCase,
    this._clearNotificationsUseCase,
  ) : super(InAppNotificationsState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_MarkReadRequested>(_onMarkReadRequested);
    on<_DeleteRequested>(_onDeleteRequested);
    on<_ClearRequested>(_onClearRequested);
  }

  final FetchNotificationsUseCase _fetchNotificationsUseCase;
  final MarkNotificationAsReadUseCase _markNotificationAsReadUseCase;
  final DeleteNotificationUseCase _deleteNotificationUseCase;
  final ClearNotificationsUseCase _clearNotificationsUseCase;

  Future<void> _onStarted(
    _Started event,
    Emitter<InAppNotificationsState> emit,
  ) {
    return _fetch(syncRemote: event.syncRemote, emit: emit);
  }

  Future<void> _onRefreshRequested(
    _RefreshRequested event,
    Emitter<InAppNotificationsState> emit,
  ) {
    return _fetch(syncRemote: true, emit: emit);
  }

  Future<void> _fetch({required bool syncRemote, required Emitter<InAppNotificationsState> emit}) async {
    emit(state.copyWith(
      status: LoadStatus.loading,
      actionStatus: ActionStatus.inProgress,
      failure: null,
    ));

    final result = await _fetchNotificationsUseCase(
      FetchNotificationsParams(syncRemote: syncRemote),
    );

    result.fold(
      onSuccess: (items) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        items: items,
        unreadCount: items.where((item) => !item.read).length,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onMarkReadRequested(
    _MarkReadRequested event,
    Emitter<InAppNotificationsState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));

    final result = await _markNotificationAsReadUseCase(MarkNotificationAsReadParams(index: event.index));

    result.fold(
      onSuccess: (items) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        items: items,
        unreadCount: items.where((item) => !item.read).length,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onDeleteRequested(
    _DeleteRequested event,
    Emitter<InAppNotificationsState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));

    final result = await _deleteNotificationUseCase(DeleteNotificationParams(index: event.index));

    result.fold(
      onSuccess: (items) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        items: items,
        unreadCount: items.where((item) => !item.read).length,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onClearRequested(
    _ClearRequested event,
    Emitter<InAppNotificationsState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));

    final result = await _clearNotificationsUseCase(const NoParams());

    result.fold(
      onSuccess: (items) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        items: items,
        unreadCount: 0,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }
}
