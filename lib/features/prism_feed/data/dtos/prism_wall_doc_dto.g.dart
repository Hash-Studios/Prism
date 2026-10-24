// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prism_wall_doc_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PrismWallDocDto _$PrismWallDocDtoFromJson(Map<String, dynamic> json) => _PrismWallDocDto(
  id: json['id'] == null ? '' : const FirestoreStringConverter().fromJson(json['id']),
  wallpaperUrl: json['wallpaper_url'] == null ? '' : const FirestoreStringConverter().fromJson(json['wallpaper_url']),
  wallpaperThumb: json['wallpaper_thumb'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['wallpaper_thumb']),
  wallpaperProvider: json['wallpaper_provider'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['wallpaper_provider']),
  resolution: json['resolution'] == null ? '' : const FirestoreStringConverter().fromJson(json['resolution']),
  fileSize: (json['file_size'] as num?)?.toInt(),
  createdAt: const FirestoreDateTimeConverter().fromJson(json['createdAt']),
  uploadedBy: json['uploadedBy'] == null ? '' : const FirestoreStringConverter().fromJson(json['uploadedBy']),
  by: json['by'] == null ? '' : const FirestoreStringConverter().fromJson(json['by']),
  email: json['email'] == null ? '' : const FirestoreStringConverter().fromJson(json['email']),
  creatorUid: json['creatorUid'] == null ? '' : const FirestoreStringConverter().fromJson(json['creatorUid']),
  userPhoto: json['userPhoto'] == null ? '' : const FirestoreStringConverter().fromJson(json['userPhoto']),
  title: json['title'] as String?,
  desc: json['desc'] == null ? '' : const FirestoreStringConverter().fromJson(json['desc']),
  collections: json['collections'] == null
      ? const <String>[]
      : const FirestoreStringListConverter().fromJson(json['collections']),
  tags: json['tags'] == null ? const <String>[] : const FirestoreStringListConverter().fromJson(json['tags']),
  category: json['category'] == null ? '' : const FirestoreStringConverter().fromJson(json['category']),
  colors: json['colors'] == null ? const <String>[] : const FirestoreStringListConverter().fromJson(json['colors']),
  review: json['review'] as bool? ?? false,
  aiMetadata: json['aiMetadata'] == null
      ? const <String, Object?>{}
      : const FirestoreJsonMapConverter().fromJson(json['aiMetadata']),
  isStreakExclusive: json['is_streak_exclusive'] as bool? ?? false,
  requiredStreakDays: (json['required_streak_days'] as num?)?.toInt(),
  streakShopCoinCost: (json['streak_shop_coin_cost'] as num?)?.toInt(),
  boostedUntil: const FirestoreDateTimeConverter().fromJson(json['boostedUntil']),
  depth: json['depth'] == null ? const <String, Object?>{} : const FirestoreJsonMapConverter().fromJson(json['depth']),
);

Map<String, dynamic> _$PrismWallDocDtoToJson(_PrismWallDocDto instance) => <String, dynamic>{
  'id': const FirestoreStringConverter().toJson(instance.id),
  'wallpaper_url': const FirestoreStringConverter().toJson(instance.wallpaperUrl),
  'wallpaper_thumb': const FirestoreStringConverter().toJson(instance.wallpaperThumb),
  'wallpaper_provider': const FirestoreStringConverter().toJson(instance.wallpaperProvider),
  'resolution': const FirestoreStringConverter().toJson(instance.resolution),
  'file_size': instance.fileSize,
  'createdAt': const FirestoreDateTimeConverter().toJson(instance.createdAt),
  'uploadedBy': const FirestoreStringConverter().toJson(instance.uploadedBy),
  'by': const FirestoreStringConverter().toJson(instance.by),
  'email': const FirestoreStringConverter().toJson(instance.email),
  'creatorUid': const FirestoreStringConverter().toJson(instance.creatorUid),
  'userPhoto': const FirestoreStringConverter().toJson(instance.userPhoto),
  'title': instance.title,
  'desc': const FirestoreStringConverter().toJson(instance.desc),
  'collections': const FirestoreStringListConverter().toJson(instance.collections),
  'tags': const FirestoreStringListConverter().toJson(instance.tags),
  'category': const FirestoreStringConverter().toJson(instance.category),
  'colors': const FirestoreStringListConverter().toJson(instance.colors),
  'review': instance.review,
  'aiMetadata': const FirestoreJsonMapConverter().toJson(instance.aiMetadata),
  'is_streak_exclusive': instance.isStreakExclusive,
  'required_streak_days': instance.requiredStreakDays,
  'streak_shop_coin_cost': instance.streakShopCoinCost,
  'boostedUntil': const FirestoreDateTimeConverter().toJson(instance.boostedUntil),
  'depth': const FirestoreJsonMapConverter().toJson(instance.depth),
};
