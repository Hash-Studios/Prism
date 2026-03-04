import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';

abstract class NotificationsRepository {
  Future<Result<List<InAppNotificationEntity>>> fetchNotifications({required bool syncRemote});

  Future<Result<List<InAppNotificationEntity>>> markAsRead({required String id});

  Future<Result<List<InAppNotificationEntity>>> deleteById({required String id});

  Future<Result<List<InAppNotificationEntity>>> clearAll();
}
