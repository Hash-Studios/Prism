import 'package:json_annotation/json_annotation.dart';

part 'wallhaven_thumb_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class WallHavenThumb {
  String large;
  String original;
  String small;

  WallHavenThumb({
    required this.large,
    required this.original,
    required this.small,
  });

  factory WallHavenThumb.fromJson(Map<String, dynamic> json) =>
      _$WallHavenThumbFromJson(json);
  Map<String, dynamic> toJson() => _$WallHavenThumbToJson(this);
}
