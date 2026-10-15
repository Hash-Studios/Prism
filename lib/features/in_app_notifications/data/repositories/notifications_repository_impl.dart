import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/notifications/notification_tombstones.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/repositories/notifications_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: NotificationsRepository)
class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._notificationsLocal, this._tombstones);

  final NotificationsLocalDataSource _notificationsLocal;
  final NotificationTombstones _tombstones;

  Future<List<InAppNotificationEntity>> _readAll() async {
    return (await _notificationsLocal.readAll()).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> fetchNotifications({required bool syncRemote}) async {
    try {
      if (syncRemote) {
        await syncInAppNotificationsFromRemote(force: true);
      } else {
        await pruneBlockedNotificationsCache(waitForInitialLoad: true, notificationsLocal: _notificationsLocal);
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
      await _tombstones.addDeleted(<String>[id]);
      await _notificationsLocal.deleteById(id);
      return Result.success(await _readAll());
    } catch (error) {
      return Result.error(CacheFailure('Unable to delete notification: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> deleteByIds({required List<String> ids}) async {
    try {
      final unique = ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList(growable: false);
      if (unique.isEmpty) {
        return Result.error(const ValidationFailure('No valid notification ids'));
      }
      await _tombstones.addDeleted(unique);
      await _notificationsLocal.deleteByIds(unique);
      return Result.success(await _readAll());
    } catch (error) {
      return Result.error(CacheFailure('Unable to delete notifications: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> clearAll() async {
    try {
      final DateTime nowUtc = DateTime.now().toUtc();
      final List<InAppNotificationEntity> current = await _notificationsLocal.readAll();
      await _tombstones.markCleared(current.map((item) => item.id), nowUtc);
      await _notificationsLocal.clearAll();
      await _notificationsLocal.setLastFetchAtUtc(nowUtc);
      return Result.success(const <InAppNotificationEntity>[]);
    } catch (error) {
      return Result.error(CacheFailure('Unable to clear notifications: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> markAllAsRead() async {
    try {
      final List<InAppNotificationEntity> current = await _notificationsLocal.readAll();
      if (current.any((item) => !item.read)) {
        await _notificationsLocal.writeAll(
          current.map((item) => item.read ? item : item.copyWith(read: true)).toList(growable: false),
        );
      }
      return Result.success(await _readAll());
    } catch (error) {
      return Result.error(CacheFailure('Unable to mark notifications as read: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> restore({required List<InAppNotificationEntity> items}) async {
    try {
      if (items.isEmpty) {
        return Result.error(const ValidationFailure('No notifications to restore'));
      }
      await _tombstones.removeDeleted(items.map((item) => item.id));
      await _notificationsLocal.upsertAll(items);
      return Result.success(await _readAll());
    } catch (error) {
      return Result.error(CacheFailure('Unable to restore notifications: $error'));
    }
  }
}
