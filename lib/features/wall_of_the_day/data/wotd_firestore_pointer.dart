import 'package:cloud_firestore/cloud_firestore.dart';

/// Payload shape for `wall_of_the_day/current` — pointer only; UI loads `walls/{wallDocumentId}`.
class WallOfTheDayFirestorePointer {
  const WallOfTheDayFirestorePointer({required this.wallDocumentId, required this.featuredAt});

  factory WallOfTheDayFirestorePointer.fromMap(Map<String, dynamic> data) {
    final String wallId = data['wallId']?.toString() ?? '';
    final Object? rawDate = data['date'];
    final DateTime featuredAt;
    if (rawDate is Timestamp) {
      featuredAt = rawDate.toDate();
    } else if (rawDate is DateTime) {
      featuredAt = rawDate;
    } else {
      featuredAt = DateTime.now();
    }
    return WallOfTheDayFirestorePointer(wallDocumentId: wallId, featuredAt: featuredAt);
  }

  final String wallDocumentId;
  final DateTime featuredAt;
}
