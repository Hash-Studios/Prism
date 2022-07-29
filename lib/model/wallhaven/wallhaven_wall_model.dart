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

  factory WallHavenWall.fromJson(Map<String, dynamic> json) => WallHavenWall(
        id: json['id'] as String,
        url: json['url'] as String,
        shortUrl: json['short_url'] as String,
        uploader:
            json['uploader'] == null ? null : WallHavenUploader.fromJson(json['uploader'] as Map<String, dynamic>),
        views: json['views'] as int,
        favorites: json['favorites'] as int,
        source: json['source'] as String,
        purity: json['purity'] as String,
        category: json['category'] as String,
        dimensionX: json['dimension_x'] as int,
        dimensionY: json['dimension_y'] as int,
        resolution: json['resolution'] as String,
        ratio: json['ratio'] as String,
        fileSize: json['file_size'] as int,
        fileType: json['file_type'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        colors: (json['colors'] as List<dynamic>).map((e) => e as String).toList(),
        path: json['path'] as String,
        thumbs: WallHavenThumb.fromJson(json['thumbs'] as Map<String, dynamic>),
        tags: (json['tags'] as List<dynamic>?)?.map((e) => WallHavenTag.fromJson(e as Map<String, dynamic>)).toList(),
      );

  @override
  Map<String, dynamic> toJson() => _$WallHavenWallToJson(this);
}
