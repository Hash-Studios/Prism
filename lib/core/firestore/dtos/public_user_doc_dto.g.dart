// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_user_doc_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicUserDocDto _$PublicUserDocDtoFromJson(Map<String, dynamic> json) =>
    _PublicUserDocDto(
      id: json['id'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['id']),
      name: json['name'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['name']),
      email: json['email'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['email']),
      username: json['username'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['username']),
      profilePhoto: json['profilePhoto'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['profilePhoto']),
      bio: json['bio'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['bio']),
      followers: json['followers'] == null
          ? const <String>[]
          : const FirestoreStringListConverter().fromJson(json['followers']),
      following: json['following'] == null
          ? const <String>[]
          : const FirestoreStringListConverter().fromJson(json['following']),
      links: json['links'] == null
          ? const <String, String>{}
          : const FirestoreStringMapConverter().fromJson(json['links']),
      premium: json['premium'] as bool? ?? false,
      coverPhoto: json['coverPhoto'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['coverPhoto']),
    );

Map<String, dynamic> _$PublicUserDocDtoToJson(
  _PublicUserDocDto instance,
) => <String, dynamic>{
  'id': const FirestoreStringConverter().toJson(instance.id),
  'name': const FirestoreStringConverter().toJson(instance.name),
  'email': const FirestoreStringConverter().toJson(instance.email),
  'username': const FirestoreStringConverter().toJson(instance.username),
  'profilePhoto': const FirestoreStringConverter().toJson(
    instance.profilePhoto,
  ),
  'bio': const FirestoreStringConverter().toJson(instance.bio),
  'followers': const FirestoreStringListConverter().toJson(instance.followers),
  'following': const FirestoreStringListConverter().toJson(instance.following),
  'links': const FirestoreStringMapConverter().toJson(instance.links),
  'premium': instance.premium,
  'coverPhoto': const FirestoreStringConverter().toJson(instance.coverPhoto),
};
