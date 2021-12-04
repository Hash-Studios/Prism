import 'package:json_annotation/json_annotation.dart';
import 'package:prism/model/wallhaven_thumb_model.dart';

part 'wallhaven_wall_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class WallHavenWall {
  String id;
  String url;
  String shortUrl;
  int views;
  int favorites;
  String source;
  String purity;
  String category;
  int dimensionX;
  int dimensionY;
  String resolution;
  String ratio;
  int fileSize;
  String fileType;
  DateTime createdAt;
  List<String> colors;
  String path;
  WallHavenThumb thumbs;

  WallHavenWall({
    required this.id,
    required this.url,
    required this.shortUrl,
    required this.views,
    required this.favorites,
    required this.source,
    required this.purity,
    required this.category,
    required this.dimensionX,
    required this.dimensionY,
    required this.resolution,
    required this.ratio,
    required this.fileSize,
    required this.fileType,
    required this.createdAt,
    required this.colors,
    required this.path,
    required this.thumbs,
  });

  factory WallHavenWall.fromJson(Map<String, dynamic> json) =>
      _$WallHavenWallFromJson(json);
  Map<String, dynamic> toJson() => _$WallHavenWallToJson(this);
}
