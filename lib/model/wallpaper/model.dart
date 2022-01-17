import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

enum WallpaperProvider {
  Prism,
  WallHaven,
  Pexels,
  PrismLive,
  PexelsLive,
}

class TimestampConverter implements JsonConverter<DateTime?, Timestamp?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Timestamp? timestamp) {
    return timestamp?.toDate();
  }

  @override
  Timestamp? toJson(DateTime? date) =>
      date == null ? null : Timestamp?.fromDate(date);
}

@JsonSerializable(explicitToJson: true)
class Wallpaper {
  String id;
  String? by;
  String? category;
  List<String>? collections;
  @TimestampConverter()
  DateTime? createdAt;
  String? desc;
  String? email;
  String? resolution;
  bool? review;
  String? size;
  String? userPhoto;
  WallpaperProvider wallpaper_provider;
  String wallpaper_thumb;
  String wallpaper_url;
  String? name;

  Wallpaper({
    required this.id,
    this.by,
    this.category,
    this.collections,
    required this.createdAt,
    this.desc,
    this.email,
    this.resolution,
    this.review,
    this.size,
    this.userPhoto,
    required this.wallpaper_provider,
    required this.wallpaper_thumb,
    required this.wallpaper_url,
    this.name,
  });

  factory Wallpaper.fromJson(Map<String, dynamic> json) =>
      _$WallpaperFromJson(json);
  Map<String, dynamic> toJson() => _$WallpaperToJson(this);
}
