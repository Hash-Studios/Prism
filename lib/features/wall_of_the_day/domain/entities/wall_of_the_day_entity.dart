import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.source = WallpaperSource.prism,
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
  /// The provider this wallpaper originates from. Defaults to [WallpaperSource.prism].
  /// Future Firestore documents may set this to [WallpaperSource.wallhaven] or
  /// [WallpaperSource.pexels] to support multi-provider WOTD.
  final WallpaperSource source;

  static WallOfTheDayEntity fromMap(Map<String, dynamic> data) {
    final rawDate = data['date'];
    DateTime date;
    if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate != null) {
      try {
        if (rawDate is Timestamp) {
          date = rawDate.toDate();
        } else {
          date = DateTime.now();
        }
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
      source: WallpaperSourceX.fromWire(data['source']),
    );
  }
}
