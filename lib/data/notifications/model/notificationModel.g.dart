// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notificationModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotifDataAdapter extends TypeAdapter<NotifData> {
  @override
  final int typeId = 0;

  @override
  NotifData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotifData(
      pageName: fields[1] as String,
      title: fields[0] as String,
      desc: fields[2] as String,
      imageUrl: fields[3] as String,
      arguments: (fields[4] as List)?.cast<dynamic>(),
      url: fields[5] as String,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, NotifData obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.pageName)
      ..writeByte(2)
      ..write(obj.desc)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.arguments)
      ..writeByte(5)
      ..write(obj.url)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotifDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
