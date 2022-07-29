import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:prism/model/pexels/pexels_src_model.dart';
import 'package:prism/model/wallpaper/model.dart';

part 'pexels_wall_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class PexelsWall extends Wallpaper {
  int width;
  int height;
  String url;
  String photographer;
  String photographerUrl;
  int photographerId;
  String avgColor;
  PexelsSrc src;
  bool liked;
  String alt;

  PexelsWall({
    required int id,
    required this.url,
    required this.width,
    required this.alt,
    required this.avgColor,
    required this.height,
    required this.liked,
    required this.photographer,
    required this.photographerId,
    required this.photographerUrl,
    required this.src,
  }) : super(
          id: id.toString(),
          wallpaper_url: url,
          createdAt: DateTime.now(),
          wallpaper_provider: WallpaperProvider.Pexels,
          wallpaper_thumb: src.small,
          by: photographer,
          resolution: "${width}x$height",
        );

  factory PexelsWall.fromJson(Map<String, dynamic> json) =>
      _$PexelsWallFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PexelsWallToJson(this);
}
