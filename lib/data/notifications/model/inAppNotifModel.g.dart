// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inAppNotifModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InAppNotifAdapter extends TypeAdapter<InAppNotif> {
  @override
  final int typeId = 9;

  @override
  InAppNotif read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return InAppNotif(
      pageName: fields[1] as String?,
      title: fields[0] as String?,
      body: fields[2] as String?,
      imageUrl: fields[3] as String?,
      arguments: (fields[4] as List?)?.cast<dynamic>(),
      url: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      read: fields[7] as bool?,
      route: fields[8] as String?,
      wallId: fields[9] as String?,
      followerEmail: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InAppNotif obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.pageName)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.arguments)
      ..writeByte(5)
      ..write(obj.url)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.read)
      ..writeByte(8)
      ..write(obj.route)
      ..writeByte(9)
      ..write(obj.wallId)
      ..writeByte(10)
      ..write(obj.followerEmail);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InAppNotifAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
