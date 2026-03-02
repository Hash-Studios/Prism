class WallOfTheDayEntity {
  const WallOfTheDayEntity({
    required this.wallId,
    required this.url,
    required this.thumbnailUrl,
    required this.title,
    required this.photographer,
    required this.photographerId,
    required this.date,
    required this.palette,
    required this.isPremium,
  });

  final String wallId;
  final String url;
  final String thumbnailUrl;
  final String title;
  final String photographer;
  final String photographerId;
  final DateTime date;
  final List<String> palette;
  final bool isPremium;

  static WallOfTheDayEntity fromMap(Map<String, dynamic> data) {
    final rawDate = data['date'];
    DateTime date;
    if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate != null) {
      try {
        date = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {
        date = DateTime.now();
      }
    } else {
      date = DateTime.now();
    }

    return WallOfTheDayEntity(
      wallId: data['wallId']?.toString() ?? '',
      url: data['url']?.toString() ?? '',
      thumbnailUrl: data['thumbnailUrl']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      photographer: data['photographer']?.toString() ?? '',
      photographerId: data['photographerId']?.toString() ?? '',
      date: date,
      palette: (data['palette'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      isPremium: data['isPremium'] as bool? ?? false,
    );
  }
}
