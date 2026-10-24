// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_user_doc_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicUserDocDto _$PublicUserDocDtoFromJson(Map<String, dynamic> json) => _PublicUserDocDto(
  name: json['name'] == null ? '' : const FirestoreStringConverter().fromJson(json['name']),
  username: json['username'] == null ? '' : const FirestoreStringConverter().fromJson(json['username']),
  profilePhoto: json['profilePhoto'] == null ? '' : const FirestoreStringConverter().fromJson(json['profilePhoto']),
  bio: json['bio'] == null ? '' : const FirestoreStringConverter().fromJson(json['bio']),
  links: json['links'] == null ? const <String, String>{} : const FirestoreStringMapConverter().fromJson(json['links']),
  coverPhoto: json['coverPhoto'] == null ? '' : const FirestoreStringConverter().fromJson(json['coverPhoto']),
  badges: json['badges'] == null ? const <String>[] : const FirestoreStringListConverter().fromJson(json['badges']),
  xp: (json['xp'] as num?)?.toInt() ?? 0,
  cosmetics: json['cosmetics'] == null
      ? const <String, String>{}
      : const FirestoreStringMapConverter().fromJson(json['cosmetics']),
  followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
  followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PublicUserDocDtoToJson(_PublicUserDocDto instance) => <String, dynamic>{
  'name': const FirestoreStringConverter().toJson(instance.name),
  'username': const FirestoreStringConverter().toJson(instance.username),
  'profilePhoto': const FirestoreStringConverter().toJson(instance.profilePhoto),
  'bio': const FirestoreStringConverter().toJson(instance.bio),
  'links': const FirestoreStringMapConverter().toJson(instance.links),
  'coverPhoto': const FirestoreStringConverter().toJson(instance.coverPhoto),
  'badges': const FirestoreStringListConverter().toJson(instance.badges),
  'xp': instance.xp,
  'cosmetics': const FirestoreStringMapConverter().toJson(instance.cosmetics),
  'followerCount': instance.followerCount,
  'followingCount': instance.followingCount,
};
