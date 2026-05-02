class BadgeEntity {
  const BadgeEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.color,
    required this.url,
    required this.awardedAt,
  });

  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String color;
  final String url;
  final String awardedAt;
}
