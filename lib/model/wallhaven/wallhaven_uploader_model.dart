import 'package:json_annotation/json_annotation.dart';
import 'package:prism/model/wallhaven/wallhaven_avatar_model.dart';

part 'wallhaven_uploader_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class WallHavenUploader {
  String username;
  String group;
  WallHavenAvatar avatar;

  WallHavenUploader({
    required this.username,
    required this.group,
    required this.avatar,
  });

  factory WallHavenUploader.fromJson(Map<String, dynamic> json) =>
      _$WallHavenUploaderFromJson(json);
  Map<String, dynamic> toJson() => _$WallHavenUploaderToJson(this);
}
