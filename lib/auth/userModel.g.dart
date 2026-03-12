// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'userModel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrismUsersV2 _$PrismUsersV2FromJson(Map<String, dynamic> json) => PrismUsersV2(
  username: json['username'] as String? ?? '',
  email: json['email'] as String? ?? '',
  id: json['id'] as String? ?? '',
  createdAt: json['createdAt'] as String? ?? '',
  premium: json['premium'] as bool? ?? false,
  lastLoginAt: json['lastLoginAt'] as String? ?? '',
  links: json['links'] is Map
      ? (json['links'] as Map).map<String, String>((dynamic key, dynamic value) {
          return MapEntry(key.toString(), value?.toString() ?? '');
        })
      : <String, String>{},
  followers:
      (json['followers'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ??
      <String>[],
  following:
      (json['following'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ??
      <String>[],
  profilePhoto: json['profilePhoto'] as String? ?? '',
  bio: json['bio'] as String? ?? '',
  loggedIn: json['loggedIn'] as bool? ?? false,
  badges:
      (json['badges'] as List<dynamic>?)
          ?.whereType<Map>()
          .map((e) => Badge.fromJson(e.map<String, dynamic>((key, value) => MapEntry(key.toString(), value))))
          .toList() ??
      <Badge>[],
  subPrisms:
      (json['subPrisms'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ??
      <String>[],
  coins: (json['coins'] as num?)?.toInt() ?? 0,
  transactions:
      (json['transactions'] as List<dynamic>?)
          ?.whereType<Map>()
          .map(
            (e) => PrismTransaction.fromJson(e.map<String, dynamic>((key, value) => MapEntry(key.toString(), value))),
          )
          .toList() ??
      <PrismTransaction>[],
  name: json['name'] as String? ?? '',
  coverPhoto: json['coverPhoto'] as String?,
  subscriptionTier: json['subscriptionTier'] as String? ?? 'free',
  uploadsWeekStart: json['uploadsWeekStart'] as String? ?? '',
  uploadsThisWeek: (json['uploadsThisWeek'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PrismUsersV2ToJson(PrismUsersV2 instance) => <String, dynamic>{
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
  'subscriptionTier': instance.subscriptionTier,
  'uploadsWeekStart': instance.uploadsWeekStart,
  'uploadsThisWeek': instance.uploadsThisWeek,
};
