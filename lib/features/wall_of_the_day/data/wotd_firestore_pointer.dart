import 'package:Prism/core/wallpaper/parse_helpers.dart';

/// Payload shape for `wall_of_the_day/current` — pointer only; UI loads `walls/{wallDocumentId}`.
class WallOfTheDayFirestorePointer {
  const WallOfTheDayFirestorePointer({required this.wallDocumentId, required this.featuredAt});

  factory WallOfTheDayFirestorePointer.fromMap(Map<String, dynamic> data) {
    return WallOfTheDayFirestorePointer(
      wallDocumentId: data['wallId']?.toString() ?? '',
      featuredAt: parseDateTime(data['date']) ?? DateTime.now(),
    );
  }

  final String wallDocumentId;
  final DateTime featuredAt;
}
