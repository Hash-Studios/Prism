import 'package:json_annotation/json_annotation.dart';

part 'wallpaper_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class SetupWallpaper {
  String id;
  String? name;
  String provider;
  String thumb;
  String url;

  SetupWallpaper({
    required this.id,
    required this.url,
    required this.provider,
    required this.thumb,
    this.name,
  });

  factory SetupWallpaper.fromJson(Map<String, dynamic> json) =>
      _$SetupWallpaperFromJson(json);
  Map<String, dynamic> toJson() => _$SetupWallpaperToJson(this);
}
