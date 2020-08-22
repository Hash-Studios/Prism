// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notificationModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotifDataAdapter extends TypeAdapter<NotifData> {
  @override
  final typeId = 0;
  @override
  NotifData read(BinaryReader reader) {
    var numOfFields = reader.readByte();
    var fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotifData(
      pageName: fields[1] as String,
      title: fields[0] as String,
      desc: fields[2] as String,
      imageUrl: fields[3] as String,
      arguments: (fields[4] as List)?.cast<dynamic>(),
      url: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NotifData obj) {
    writer
      ..writeByte(6)
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
      ..write(obj.url);
  }
}
