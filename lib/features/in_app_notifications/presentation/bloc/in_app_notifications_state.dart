part of 'in_app_notifications_bloc.dart';

@freezed
abstract class InAppNotificationsState with _$InAppNotificationsState {
  const factory InAppNotificationsState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required List<InAppNotificationEntity> items,
    required int unreadCount,
    Failure? failure,
  }) = _InAppNotificationsState;

  factory InAppNotificationsState.initial() => const InAppNotificationsState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        items: <InAppNotificationEntity>[],
        unreadCount: 0,
      );
}
