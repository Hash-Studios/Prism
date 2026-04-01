import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/repositories/notifications_repository.dart';
import 'package:injectable/injectable.dart';

class FetchNotificationsParams {
  const FetchNotificationsParams({required this.syncRemote});

  final bool syncRemote;
}

@lazySingleton
class FetchNotificationsUseCase implements UseCase<List<InAppNotificationEntity>, FetchNotificationsParams> {
  FetchNotificationsUseCase(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<Result<List<InAppNotificationEntity>>> call(FetchNotificationsParams params) {
    return _repository.fetchNotifications(syncRemote: params.syncRemote);
  }
}

class MarkNotificationAsReadParams {
  const MarkNotificationAsReadParams({required this.id});

  final String id;
}

@lazySingleton
class MarkNotificationAsReadUseCase implements UseCase<List<InAppNotificationEntity>, MarkNotificationAsReadParams> {
  MarkNotificationAsReadUseCase(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<Result<List<InAppNotificationEntity>>> call(MarkNotificationAsReadParams params) {
    return _repository.markAsRead(id: params.id);
  }
}

class DeleteNotificationParams {
  const DeleteNotificationParams({required this.id});

  final String id;
}

@lazySingleton
class DeleteNotificationUseCase implements UseCase<List<InAppNotificationEntity>, DeleteNotificationParams> {
  DeleteNotificationUseCase(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<Result<List<InAppNotificationEntity>>> call(DeleteNotificationParams params) {
    return _repository.deleteById(id: params.id);
  }
}

@lazySingleton
class ClearNotificationsUseCase implements UseCase<List<InAppNotificationEntity>, NoParams> {
  ClearNotificationsUseCase(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<Result<List<InAppNotificationEntity>>> call(NoParams params) {
    return _repository.clearAll();
  }
}

class DeleteNotificationsByIdsParams {
  const DeleteNotificationsByIdsParams({required this.ids});

  final List<String> ids;
}

@lazySingleton
class DeleteNotificationsByIdsUseCase
    implements UseCase<List<InAppNotificationEntity>, DeleteNotificationsByIdsParams> {
  DeleteNotificationsByIdsUseCase(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<Result<List<InAppNotificationEntity>>> call(DeleteNotificationsByIdsParams params) {
    return _repository.deleteByIds(ids: params.ids);
  }
}
