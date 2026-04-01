part of 'in_app_notifications_bloc.j.dart';

@freezed
abstract class InAppNotificationsEvent with _$InAppNotificationsEvent {
  const factory InAppNotificationsEvent.started({@Default(false) bool syncRemote}) = _Started;
  const factory InAppNotificationsEvent.localReloadRequested() = _LocalReloadRequested;
  const factory InAppNotificationsEvent.refreshRequested() = _RefreshRequested;
  const factory InAppNotificationsEvent.markReadRequested({required String id}) = _MarkReadRequested;
  const factory InAppNotificationsEvent.deleteRequested({required String id}) = _DeleteRequested;
  const factory InAppNotificationsEvent.clearRequested() = _ClearRequested;
}
