import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/repositories/notifications_repository.dart';
import 'package:hive_io/hive_io.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: NotificationsRepository)
class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(@Named('inAppNotificationsBox') this._box);

  final Box<InAppNotif> _box;

  List<InAppNotificationEntity> _readAll() {
    final values = _box.values.toList(growable: false);
    return values
        .map((item) {
          return InAppNotificationEntity(
            title: item.title ?? '',
            pageName: item.pageName ?? '',
            body: item.body ?? '',
            imageUrl: item.imageUrl ?? '',
            arguments: item.arguments ?? const <dynamic>[],
            url: item.url ?? '',
            createdAt: item.createdAt ?? DateTime.now(),
            read: item.read ?? false,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> fetchNotifications({required bool syncRemote}) async {
    try {
      if (syncRemote) {
        await getNotifs();
      }
      return Result.success(_readAll());
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch notifications: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> markAsRead({required int index}) async {
    try {
      if (index < 0 || index >= _box.length) {
        return Result.error(const ValidationFailure('Invalid index'));
      }

      final existing = _box.getAt(index);
      if (existing != null) {
        await _box.putAt(
          index,
          InAppNotif(
            title: existing.title,
            pageName: existing.pageName,
            body: existing.body,
            imageUrl: existing.imageUrl,
            arguments: existing.arguments,
            url: existing.url,
            createdAt: existing.createdAt,
            read: true,
            route: existing.route,
            wallId: existing.wallId,
          ),
        );
      }

      return Result.success(_readAll());
    } catch (error) {
      return Result.error(CacheFailure('Unable to mark notification as read: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> deleteAt({required int index}) async {
    try {
      if (index < 0 || index >= _box.length) {
        return Result.error(const ValidationFailure('Invalid index'));
      }
      await _box.deleteAt(index);
      return Result.success(_readAll());
    } catch (error) {
      return Result.error(CacheFailure('Unable to delete notification: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> clearAll() async {
    try {
      await _box.clear();
      return Result.success(const <InAppNotificationEntity>[]);
    } catch (error) {
      return Result.error(CacheFailure('Unable to clear notifications: $error'));
    }
  }
}
