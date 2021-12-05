import 'package:json_annotation/json_annotation.dart';

part 'wallhaven_search_meta_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class WallHavenSearchMeta {
  int currentPage;
  int lastPage;
  int perPage;
  int total;
  String? query;
  String? seed;

  WallHavenSearchMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.query,
    this.seed,
  });

  factory WallHavenSearchMeta.fromJson(Map<String, dynamic> json) =>
      _$WallHavenSearchMetaFromJson(json);
  Map<String, dynamic> toJson() => _$WallHavenSearchMetaToJson(this);
}
