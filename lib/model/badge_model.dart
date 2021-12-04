import 'package:json_annotation/json_annotation.dart';
import 'package:prism/services/logger.dart';

part 'badge_model.g.dart';

@JsonSerializable(
  explicitToJson: true,
)
class Badge {
  String name;
  String description;
  String id;
  String awardedAt;
  String imageUrl;
  String color;
  String url;

  Badge({
    required this.name,
    required this.description,
    required this.id,
    required this.awardedAt,
    required this.imageUrl,
    required this.color,
    required this.url,
  }) {
    logger.d("Default constructor !!!!");
  }

  factory Badge.fromJson(Map<String, dynamic> json) => _$BadgeFromJson(json);
  Map<String, dynamic> toJson() => _$BadgeToJson(this);
}
