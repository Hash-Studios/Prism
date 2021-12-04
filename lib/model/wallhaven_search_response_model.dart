import 'package:json_annotation/json_annotation.dart';
import 'package:prism/model/wallhaven_search_meta_model.dart';
import 'package:prism/model/wallhaven_wall_model.dart';

part 'wallhaven_search_response_model.g.dart';

@JsonSerializable(
  explicitToJson: true,
)
class WallHavenSearchResponse {
  List<WallHavenWall> data;
  WallHavenSearchMeta meta;

  WallHavenSearchResponse({
    required this.data,
    required this.meta,
  });

  factory WallHavenSearchResponse.fromJson(Map<String, dynamic> json) =>
      _$WallHavenSearchResponseFromJson(json);
  Map<String, dynamic> toJson() => _$WallHavenSearchResponseToJson(this);
}
