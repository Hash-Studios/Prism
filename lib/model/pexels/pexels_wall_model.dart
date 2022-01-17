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
          wallpaper_provider: "Pexels",
          wallpaper_thumb: src.small,
          by: photographer,
          resolution: "${width}x$height",
        );

  factory PexelsWall.fromJson(Map<String, dynamic> json) => PexelsWall(
        id: json['id'] as int,
        url: json['url'] as String,
        width: json['width'] as int,
        alt: json['alt'] as String,
        avgColor: json['avg_color'] as String,
        height: json['height'] as int,
        liked: json['liked'] as bool,
        photographer: json['photographer'] as String,
        photographerId: json['photographer_id'] as int,
        photographerUrl: json['photographer_url'] as String,
        src: PexelsSrc.fromJson(json['src'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => _$PexelsWallToJson(this);
}
