class InAppNotificationEntity {
  const InAppNotificationEntity({
    required this.title,
    required this.pageName,
    required this.body,
    required this.imageUrl,
    required this.arguments,
    required this.url,
    required this.createdAt,
    required this.read,
  });

  final String title;
  final String pageName;
  final String body;
  final String imageUrl;
  final List<Object> arguments;
  final String url;
  final DateTime createdAt;
  final bool read;
}
