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

  ({String ownerId, int localGeneration, int tombstoneGeneration}) _captureSession() {
    final String ownerId = _notificationsLocal.ownerId;
    _tombstones.setOwner(ownerId);
    return (
      ownerId: ownerId,
      localGeneration: _notificationsLocal.ownerGeneration,
      tombstoneGeneration: _tombstones.ownerGeneration,
    );
  }

  bool _isCurrent(({String ownerId, int localGeneration, int tombstoneGeneration}) session) =>
      session.ownerId == _notificationsLocal.ownerId &&
      session.localGeneration == _notificationsLocal.ownerGeneration &&
      session.ownerId == _tombstones.ownerId &&
      session.tombstoneGeneration == _tombstones.ownerGeneration;

  Future<List<InAppNotificationEntity>> _readAll(
    ({String ownerId, int localGeneration, int tombstoneGeneration}) session,
  ) async {
    final items = (await _notificationsLocal.readAll()).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _isCurrent(session) ? items : const <InAppNotificationEntity>[];
  }

  Result<List<InAppNotificationEntity>> _sessionChanged() =>
      Result.error(const CacheFailure('Notification session changed before the operation completed'));

  Result<List<InAppNotificationEntity>> _successIfCurrent(
    ({String ownerId, int localGeneration, int tombstoneGeneration}) session,
    List<InAppNotificationEntity> items,
  ) => _isCurrent(session) ? Result.success(items) : _sessionChanged();

  Future<Result<List<InAppNotificationEntity>>> _afterWrite(
    ({String ownerId, int localGeneration, int tombstoneGeneration}) session,
  ) async {
    if (!_isCurrent(session)) return _sessionChanged();
    if (!await pruneBlockedNotificationsCache(notificationsLocal: _notificationsLocal)) {
      return Result.error(const ServerFailure('Unable to read notifications: blocked accounts did not load'));
    }
    if (!_isCurrent(session)) return _sessionChanged();
    return _successIfCurrent(session, await _readAll(session));
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> fetchNotifications({required bool syncRemote}) async {
    final session = _captureSession();
    try {
      if (syncRemote) await syncInAppNotificationsFromRemote(force: true);
      if (!await pruneBlockedNotificationsCache(notificationsLocal: _notificationsLocal)) {
        return Result.error(const ServerFailure('Unable to fetch notifications: blocked accounts did not load'));
      }
      return _successIfCurrent(session, await _readAll(session));
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch notifications: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> markAsRead({required String id}) async {
    final session = _captureSession();
    try {
      if (id.trim().isEmpty) {
        return Result.error(const ValidationFailure('Invalid notification id'));
      }
      await _notificationsLocal.markAsRead(id);
      return await _afterWrite(session);
    } catch (error) {
      return Result.error(CacheFailure('Unable to mark notification as read: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> deleteById({required String id}) async {
    final session = _captureSession();
    try {
      if (id.trim().isEmpty) {
        return Result.error(const ValidationFailure('Invalid notification id'));
      }
      await _tombstones.addDeleted(<String>[id]);
      if (!_isCurrent(session)) return _sessionChanged();
      await _notificationsLocal.deleteById(id);
      return await _afterWrite(session);
    } catch (error) {
      return Result.error(CacheFailure('Unable to delete notification: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> deleteByIds({required List<String> ids}) async {
    final session = _captureSession();
    try {
      final unique = ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList(growable: false);
      if (unique.isEmpty) {
        return Result.error(const ValidationFailure('No valid notification ids'));
      }
      await _tombstones.addDeleted(unique);
      if (!_isCurrent(session)) return _sessionChanged();
      await _notificationsLocal.deleteByIds(unique);
      return await _afterWrite(session);
    } catch (error) {
      return Result.error(CacheFailure('Unable to delete notifications: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> clearAll() async {
    final session = _captureSession();
    try {
      final DateTime nowUtc = DateTime.now().toUtc();
      final List<InAppNotificationEntity> current = await _notificationsLocal.readAll();
      if (!_isCurrent(session)) return _sessionChanged();
      await _tombstones.markCleared(current.map((item) => item.id), nowUtc);
      if (!_isCurrent(session)) return _sessionChanged();
      await _notificationsLocal.clearAll();
      if (!_isCurrent(session)) return _sessionChanged();
      await _notificationsLocal.setLastFetchAtUtc(nowUtc);
      return _successIfCurrent(session, const <InAppNotificationEntity>[]);
    } catch (error) {
      return Result.error(CacheFailure('Unable to clear notifications: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> markAllAsRead() async {
    final session = _captureSession();
    try {
      final List<InAppNotificationEntity> current = await _notificationsLocal.readAll();
      if (!_isCurrent(session)) return _sessionChanged();
      if (current.any((item) => !item.read)) {
        await _notificationsLocal.writeAll(
          current.map((item) => item.read ? item : item.copyWith(read: true)).toList(growable: false),
        );
        if (!_isCurrent(session)) return _sessionChanged();
      }
      return await _afterWrite(session);
    } catch (error) {
      return Result.error(CacheFailure('Unable to mark notifications as read: $error'));
    }
  }

  @override
  Future<Result<List<InAppNotificationEntity>>> restore({required List<InAppNotificationEntity> items}) async {
    final session = _captureSession();
    try {
      if (items.isEmpty) {
        return Result.error(const ValidationFailure('No notifications to restore'));
      }
      await _tombstones.restore(items);
      if (!_isCurrent(session)) return _sessionChanged();
      await _notificationsLocal.upsertAll(items);
      return await _afterWrite(session);
    } catch (error) {
      return Result.error(CacheFailure('Unable to restore notifications: $error'));
    }
  }
}
