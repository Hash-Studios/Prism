import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'badgeModel.g.dart';

@HiveType(typeId: 12)
@JsonSerializable(
  explicitToJson: true,
)
class Badge {
  @HiveField(0)
  String name;
  @HiveField(1)
  String description;
  @HiveField(2)
  String id;
  @HiveField(3)
  String awardedAt;
  @HiveField(4)
  String imageUrl;
  @HiveField(5)
  String color;
  @HiveField(6)
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
    debugPrint("Default constructor !!!!");
  }

  factory Badge.fromJson(Map<String, dynamic> json) => _$BadgeFromJson(json);
  Map<String, dynamic> toJson() => _$BadgeToJson(this);
}
