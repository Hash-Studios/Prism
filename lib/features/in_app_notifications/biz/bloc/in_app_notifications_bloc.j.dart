import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/usecases/notifications_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'in_app_notifications_event.j.dart';
part 'in_app_notifications_state.j.dart';
part 'in_app_notifications_bloc.j.freezed.dart';

@lazySingleton
class InAppNotificationsBloc extends Bloc<InAppNotificationsEvent, InAppNotificationsState> {
  InAppNotificationsBloc(
    this._fetchNotificationsUseCase,
    this._markNotificationAsReadUseCase,
    this._deleteNotificationUseCase,
    this._deleteNotificationsByIdsUseCase,
    this._clearNotificationsUseCase,
    this._markAllNotificationsAsReadUseCase,
    this._restoreNotificationsUseCase,
  ) : super(InAppNotificationsState.initial()) {
    on<_Started>(_onStarted);
    on<_LocalReloadRequested>(_onLocalReloadRequested);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_MarkReadRequested>(_onMarkReadRequested);
    on<_DeleteRequested>(_onDeleteRequested);
    on<_DeleteManyRequested>(_onDeleteManyRequested);
    on<_ClearRequested>(_onClearRequested);
    on<_MarkAllReadRequested>(_onMarkAllReadRequested);
    on<_RestoreRequested>(_onRestoreRequested);
  }

  final FetchNotificationsUseCase _fetchNotificationsUseCase;
  final MarkNotificationAsReadUseCase _markNotificationAsReadUseCase;
  final DeleteNotificationUseCase _deleteNotificationUseCase;
  final DeleteNotificationsByIdsUseCase _deleteNotificationsByIdsUseCase;
  final ClearNotificationsUseCase _clearNotificationsUseCase;
  final MarkAllNotificationsAsReadUseCase _markAllNotificationsAsReadUseCase;
  final RestoreNotificationsUseCase _restoreNotificationsUseCase;

  Future<void> _onStarted(_Started event, Emitter<InAppNotificationsState> emit) {
    return _fetch(syncRemote: event.syncRemote, emit: emit);
  }

  Future<void> _onRefreshRequested(_RefreshRequested event, Emitter<InAppNotificationsState> emit) {
    return _fetch(syncRemote: true, emit: emit);
  }

  Future<void> _onLocalReloadRequested(_LocalReloadRequested event, Emitter<InAppNotificationsState> emit) async {
    _apply(await _fetchNotificationsUseCase(const FetchNotificationsParams(syncRemote: false)), emit);
  }

  Future<void> _fetch({required bool syncRemote, required Emitter<InAppNotificationsState> emit}) async {
    emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress, failure: null));
    _apply(await _fetchNotificationsUseCase(FetchNotificationsParams(syncRemote: syncRemote)), emit, failLoad: true);
  }

  Future<void> _onMarkReadRequested(_MarkReadRequested event, Emitter<InAppNotificationsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    _apply(await _markNotificationAsReadUseCase(MarkNotificationAsReadParams(id: event.id)), emit);
  }

  Future<void> _onDeleteRequested(_DeleteRequested event, Emitter<InAppNotificationsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    _apply(await _deleteNotificationUseCase(DeleteNotificationParams(id: event.id)), emit);
  }

  Future<void> _onDeleteManyRequested(_DeleteManyRequested event, Emitter<InAppNotificationsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    _apply(await _deleteNotificationsByIdsUseCase(DeleteNotificationsByIdsParams(ids: event.ids)), emit);
  }

  Future<void> _onClearRequested(_ClearRequested event, Emitter<InAppNotificationsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    _apply(await _clearNotificationsUseCase(const NoParams()), emit);
  }

  Future<void> _onMarkAllReadRequested(_MarkAllReadRequested event, Emitter<InAppNotificationsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    _apply(await _markAllNotificationsAsReadUseCase(const NoParams()), emit);
  }

  Future<void> _onRestoreRequested(_RestoreRequested event, Emitter<InAppNotificationsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    _apply(await _restoreNotificationsUseCase(RestoreNotificationsParams(items: event.items)), emit);
  }

  /// Publishes the new item list, or the failure. [failLoad] also marks the whole load as failed.
  void _apply(
    Result<List<InAppNotificationEntity>> result,
    Emitter<InAppNotificationsState> emit, {
    bool failLoad = false,
  }) {
    result.fold(
      onSuccess: (items) => emit(
        state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: items,
          unreadCount: items.where((item) => !item.read).length,
          failure: null,
        ),
      ),
      onFailure: (failure) => emit(
        state.copyWith(
          status: failLoad ? LoadStatus.failure : state.status,
          actionStatus: ActionStatus.failure,
          failure: failure,
        ),
      ),
    );
  }
}
