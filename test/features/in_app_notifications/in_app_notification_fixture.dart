import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';

InAppNotificationEntity notification(
  String id, {
  String title = 't',
  String body = 'b',
  DateTime? createdAt,
  bool read = false,
  String? followerEmail,
}) {
  return InAppNotificationEntity(
    id: id,
    title: title,
    pageName: '/route',
    body: body,
    imageUrl: '',
    arguments: const <Object>[],
    url: '',
    createdAt: createdAt ?? DateTime.utc(2024),
    read: read,
    followerEmail: followerEmail,
  );
}
