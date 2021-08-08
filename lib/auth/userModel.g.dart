// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'userModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrismUsersV2Adapter extends TypeAdapter<PrismUsersV2> {
  @override
  final int typeId = 15;

  @override
  PrismUsersV2 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrismUsersV2(
      username: fields[0] as String,
      email: fields[1] as String,
      id: fields[2] as String,
      createdAt: fields[3] as String,
      premium: fields[4] as bool,
      lastLoginAt: fields[5] as String,
      links: (fields[6] as Map).cast<dynamic, dynamic>(),
      followers: (fields[7] as List).cast<dynamic>(),
      following: (fields[8] as List).cast<dynamic>(),
      profilePhoto: fields[9] as String,
      bio: fields[10] as String,
      loggedIn: fields[11] as bool,
      badges: (fields[12] as List).cast<Badge>(),
      subPrisms: (fields[13] as List).cast<dynamic>(),
      coins: fields[14] as int,
      transactions: (fields[15] as List).cast<PrismTransaction>(),
      name: fields[16] as String,
      coverPhoto: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PrismUsersV2 obj) {
    writer
      ..writeByte(18)
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
      ..write(obj.lastLoginAt)
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
      ..write(obj.loggedIn)
      ..writeByte(12)
      ..write(obj.badges)
      ..writeByte(13)
      ..write(obj.subPrisms)
      ..writeByte(14)
      ..write(obj.coins)
      ..writeByte(15)
      ..write(obj.transactions)
      ..writeByte(16)
      ..write(obj.name)
      ..writeByte(17)
      ..write(obj.coverPhoto);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismUsersV2Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrismUsersV2 _$PrismUsersV2FromJson(Map<String, dynamic> json) {
  return PrismUsersV2(
    username: json['username'] as String,
    email: json['email'] as String,
    id: json['id'] as String,
    createdAt: json['createdAt'] as String,
    premium: json['premium'] as bool,
    lastLoginAt: json['lastLoginAt'] as String,
    links: json['links'] as Map<String, dynamic>,
    followers: json['followers'] as List<dynamic>,
    following: json['following'] as List<dynamic>,
    profilePhoto: json['profilePhoto'] as String,
    bio: json['bio'] as String,
    loggedIn: json['loggedIn'] as bool,
    badges: (json['badges'] as List<dynamic>)
        .map((e) => Badge.fromJson(e as Map<String, dynamic>))
        .toList(),
    subPrisms: json['subPrisms'] as List<dynamic>,
    coins: json['coins'] as int,
    transactions: (json['transactions'] as List<dynamic>)
        .map((e) => PrismTransaction.fromJson(e as Map<String, dynamic>))
        .toList(),
    name: json['name'] as String,
    coverPhoto: json['coverPhoto'] as String?,
  );
}

Map<String, dynamic> _$PrismUsersV2ToJson(PrismUsersV2 instance) =>
    <String, dynamic>{
      'username': instance.username,
      'email': instance.email,
      'id': instance.id,
      'createdAt': instance.createdAt,
      'premium': instance.premium,
      'lastLoginAt': instance.lastLoginAt,
      'links': instance.links,
      'followers': instance.followers,
      'following': instance.following,
      'profilePhoto': instance.profilePhoto,
      'bio': instance.bio,
      'loggedIn': instance.loggedIn,
      'badges': instance.badges.map((e) => e.toJson()).toList(),
      'subPrisms': instance.subPrisms,
      'coins': instance.coins,
      'transactions': instance.transactions.map((e) => e.toJson()).toList(),
      'name': instance.name,
      'coverPhoto': instance.coverPhoto,
    };
