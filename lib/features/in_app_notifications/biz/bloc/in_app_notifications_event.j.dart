part of 'in_app_notifications_bloc.j.dart';

@freezed
abstract class InAppNotificationsEvent with _$InAppNotificationsEvent {
  const factory InAppNotificationsEvent.started({@Default(false) bool syncRemote}) = _Started;
  const factory InAppNotificationsEvent.localReloadRequested() = _LocalReloadRequested;
  const factory InAppNotificationsEvent.refreshRequested() = _RefreshRequested;
  const factory InAppNotificationsEvent.markReadRequested({required String id}) = _MarkReadRequested;
  const factory InAppNotificationsEvent.deleteRequested({required String id}) = _DeleteRequested;
  const factory InAppNotificationsEvent.deleteManyRequested({required List<String> ids}) = _DeleteManyRequested;
  const factory InAppNotificationsEvent.clearRequested() = _ClearRequested;
  const factory InAppNotificationsEvent.markAllReadRequested() = _MarkAllReadRequested;
  const factory InAppNotificationsEvent.restoreRequested({required List<InAppNotificationEntity> items}) =
      _RestoreRequested;
}
