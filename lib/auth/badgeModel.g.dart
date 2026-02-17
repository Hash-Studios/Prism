// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badgeModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BadgeAdapter extends TypeAdapter<Badge> {
  @override
  final int typeId = 12;

  @override
  Badge read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Badge(
      name: fields[0] as String,
      description: fields[1] as String,
      id: fields[2] as String,
      awardedAt: fields[3] as String,
      imageUrl: fields[4] as String,
      color: fields[5] as String,
      url: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Badge obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.awardedAt)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.color)
      ..writeByte(6)
      ..write(obj.url);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BadgeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
