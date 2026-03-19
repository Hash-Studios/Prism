// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'userModel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrismUsersV2 _$PrismUsersV2FromJson(Map<String, dynamic> json) => PrismUsersV2(
  username: json['username'] as String,
  email: json['email'] as String,
  id: json['id'] as String,
  createdAt: json['createdAt'] as String,
  premium: json['premium'] as bool,
  lastLoginAt: json['lastLoginAt'] as String,
  links: Map<String, String>.from(json['links'] as Map),
  followers: (json['followers'] as List<dynamic>).map((e) => e as String).toList(),
  following: (json['following'] as List<dynamic>).map((e) => e as String).toList(),
  profilePhoto: json['profilePhoto'] as String,
  bio: json['bio'] as String,
  loggedIn: json['loggedIn'] as bool,
  badges: (json['badges'] as List<dynamic>).map((e) => Badge.fromJson(e as Map<String, dynamic>)).toList(),
  subPrisms: (json['subPrisms'] as List<dynamic>).map((e) => e as String).toList(),
  coins: (json['coins'] as num).toInt(),
  transactions: (json['transactions'] as List<dynamic>)
      .map((e) => PrismTransaction.fromJson(e as Map<String, dynamic>))
      .toList(),
  name: json['name'] as String,
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
