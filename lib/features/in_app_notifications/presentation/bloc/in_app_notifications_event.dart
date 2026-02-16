part of 'in_app_notifications_bloc.dart';

@freezed
abstract class InAppNotificationsEvent with _$InAppNotificationsEvent {
  const factory InAppNotificationsEvent.started({@Default(false) bool syncRemote}) = _Started;
  const factory InAppNotificationsEvent.refreshRequested() = _RefreshRequested;
  const factory InAppNotificationsEvent.markReadRequested({required int index}) = _MarkReadRequested;
  const factory InAppNotificationsEvent.deleteRequested({required int index}) = _DeleteRequested;
  const factory InAppNotificationsEvent.clearRequested() = _ClearRequested;
}
