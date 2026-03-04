class InAppNotificationEntity {
  const InAppNotificationEntity({
    required this.id,
    required this.title,
    required this.pageName,
    required this.body,
    required this.imageUrl,
    required this.arguments,
    required this.url,
    required this.createdAt,
    required this.read,
    this.route,
    this.wallId,
  });

  final String id;
  final String title;
  final String pageName;
  final String body;
  final String imageUrl;
  final List<Object> arguments;
  final String url;
  final DateTime createdAt;
  final bool read;
  final String? route;
  final String? wallId;

  InAppNotificationEntity copyWith({
    String? id,
    String? title,
    String? pageName,
    String? body,
    String? imageUrl,
    List<Object>? arguments,
    String? url,
    DateTime? createdAt,
    bool? read,
    String? route,
    String? wallId,
  }) {
    return InAppNotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      pageName: pageName ?? this.pageName,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      arguments: arguments ?? this.arguments,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      route: route ?? this.route,
      wallId: wallId ?? this.wallId,
    );
  }
}
