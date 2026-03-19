// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badgeModel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Badge _$BadgeFromJson(Map<String, dynamic> json) => Badge(
  name: json['name'] as String,
  description: json['description'] as String,
  id: json['id'] as String,
  awardedAt: json['awardedAt'] as String,
  imageUrl: json['imageUrl'] as String,
  color: json['color'] as String,
  url: json['url'] as String,
);

Map<String, dynamic> _$BadgeToJson(Badge instance) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'id': instance.id,
  'awardedAt': instance.awardedAt,
  'imageUrl': instance.imageUrl,
  'color': instance.color,
  'url': instance.url,
};
