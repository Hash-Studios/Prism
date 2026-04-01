import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/repositories/notifications_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: NotificationsRepository)
class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._notificationsLocal);

  final NotificationsLocalDataSource _notificationsLocal;

  Future<List<InAppNotificationEntity>> _readAll() async {
    final items = (await _notificationsLocal.readAll()).toList(growable: false);
    final sorted = items.toList(growable: false)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> fetchNotifications({required bool syncRemote}) async {
    try {
      if (syncRemote) {
        await syncInAppNotificationsFromRemote();
      }
      return Result.success(await _readAll());
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch notifications: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> markAsRead({required String id}) async {
    try {
      if (id.trim().isEmpty) {
        return Result.error(const ValidationFailure('Invalid notification id'));
      }
      await _notificationsLocal.markAsRead(id);
      return Result.success(await _readAll());
    } catch (error) {
      return Result.error(CacheFailure('Unable to mark notification as read: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> deleteById({required String id}) async {
    try {
      if (id.trim().isEmpty) {
        return Result.error(const ValidationFailure('Invalid notification id'));
      }
      await _notificationsLocal.deleteById(id);
      return Result.success(await _readAll());
    } catch (error) {
      return Result.error(CacheFailure('Unable to delete notification: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> clearAll() async {
    try {
      await _notificationsLocal.clearAll();
      await _notificationsLocal.clearLastFetchAtUtc();
      return Result.success(const <InAppNotificationEntity>[]);
    } catch (error) {
      return Result.error(CacheFailure('Unable to clear notifications: $error'));
    }
  }
}
