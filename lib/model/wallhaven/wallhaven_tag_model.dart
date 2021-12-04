import 'package:json_annotation/json_annotation.dart';

part 'wallhaven_tag_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class WallHavenTag {
  int id;
  String name;
  String alias;
  int categoryId;
  String category;
  String purity;
  DateTime createdAt;

  WallHavenTag({
    required this.id,
    required this.name,
    required this.alias,
    required this.categoryId,
    required this.category,
    required this.purity,
    required this.createdAt,
  });

  factory WallHavenTag.fromJson(Map<String, dynamic> json) =>
      _$WallHavenTagFromJson(json);
  Map<String, dynamic> toJson() => _$WallHavenTagToJson(this);
}
