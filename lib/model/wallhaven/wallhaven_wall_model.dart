import 'package:json_annotation/json_annotation.dart';
import 'package:prism/model/wallhaven/wallhaven_tag_model.dart';
import 'package:prism/model/wallhaven/wallhaven_thumb_model.dart';
import 'package:prism/model/wallhaven/wallhaven_uploader_model.dart';
import 'package:prism/model/wallpaper/model.dart';

part 'wallhaven_wall_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class WallHavenWall extends Wallpaper {
  String url;
  String shortUrl;
  WallHavenUploader? uploader;
  int views;
  int favorites;
  String source;
  String purity;
  int dimensionX;
  int dimensionY;
  String ratio;
  int fileSize;
  String fileType;
  List<String> colors;
  String path;
  WallHavenThumb thumbs;
  List<WallHavenTag>? tags;

  WallHavenWall({
    required String id,
    required this.url,
    required this.shortUrl,
    this.uploader,
    required this.views,
    required this.favorites,
    required this.source,
    required this.purity,
    required String category,
    required this.dimensionX,
    required this.dimensionY,
    required String resolution,
    required this.ratio,
    required this.fileSize,
    required this.fileType,
    required DateTime createdAt,
    required this.colors,
    required this.path,
    required this.thumbs,
    this.tags,
  }) : super(
          id: id,
          wallpaper_url: url,
          createdAt: createdAt,
          wallpaper_provider: WallpaperProvider.WallHaven,
          wallpaper_thumb: thumbs.original,
          category: category,
          by: uploader?.username,
          resolution: resolution,
          size: fileSize.toString(),
        );

  factory WallHavenWall.fromJson(Map<String, dynamic> json) =>
      _$WallHavenWallFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$WallHavenWallToJson(this);
}
