import 'package:json_annotation/json_annotation.dart';

part 'wallhaven_avatar_model.g.dart';

@JsonSerializable(explicitToJson: true)
class WallHavenAvatar {
  @JsonKey(name: '200px')
  String large;
  @JsonKey(name: '128px')
  String original;
  @JsonKey(name: '32px')
  String small;
  @JsonKey(name: '20px')
  String tiny;

  WallHavenAvatar({
    required this.large,
    required this.original,
    required this.small,
    required this.tiny,
  });

  factory WallHavenAvatar.fromJson(Map<String, dynamic> json) =>
      _$WallHavenAvatarFromJson(json);
  Map<String, dynamic> toJson() => _$WallHavenAvatarToJson(this);
}
