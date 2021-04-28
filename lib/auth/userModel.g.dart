// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'userModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrismUsersAdapter extends TypeAdapter<PrismUsers> {
  @override
  final int typeId = 1;

  @override
  PrismUsers read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrismUsers(
      username: fields[0] as String,
      email: fields[1] as String,
      id: fields[2] as String,
      createdAt: fields[3] as String,
      premium: fields[4] as bool,
      lastLogin: fields[5] as DateTime,
      links: fields[6] as Map,
      followers: fields[7] as List,
      following: fields[8] as List,
      profilePhoto: fields[9] as String,
      bio: fields[10] as String,
      loggedIn: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PrismUsers obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.premium)
      ..writeByte(5)
      ..write(obj.lastLogin)
      ..writeByte(6)
      ..write(obj.links)
      ..writeByte(7)
      ..write(obj.followers)
      ..writeByte(8)
      ..write(obj.following)
      ..writeByte(9)
      ..write(obj.profilePhoto)
      ..writeByte(10)
      ..write(obj.bio)
      ..writeByte(11)
      ..write(obj.loggedIn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismUsersAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
