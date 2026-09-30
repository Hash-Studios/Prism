// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wall_doc_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WallDocDto _$WallDocDtoFromJson(Map<String, dynamic> json) => _WallDocDto(
  id: json['id'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['id']),
  by: json['by'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['by']),
  desc: json['desc'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['desc']),
  size: json['size'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['size']),
  resolution: json['resolution'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['resolution']),
  email: json['email'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['email']),
  wallpaperProvider: json['wallpaper_provider'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['wallpaper_provider']),
  wallpaperThumb: json['wallpaper_thumb'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['wallpaper_thumb']),
  wallpaperUrl: json['wallpaper_url'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['wallpaper_url']),
  collections: json['collections'] == null
      ? const <String>[]
      : const FirestoreStringListConverter().fromJson(json['collections']),
  createdAt: const FirestoreDateTimeConverter().fromJson(json['createdAt']),
  review: json['review'] as bool? ?? false,
);

Map<String, dynamic> _$WallDocDtoToJson(
  _WallDocDto instance,
) => <String, dynamic>{
  'id': const FirestoreStringConverter().toJson(instance.id),
  'by': const FirestoreStringConverter().toJson(instance.by),
  'desc': const FirestoreStringConverter().toJson(instance.desc),
  'size': const FirestoreStringConverter().toJson(instance.size),
  'resolution': const FirestoreStringConverter().toJson(instance.resolution),
  'email': const FirestoreStringConverter().toJson(instance.email),
  'wallpaper_provider': const FirestoreStringConverter().toJson(
    instance.wallpaperProvider,
  ),
  'wallpaper_thumb': const FirestoreStringConverter().toJson(
    instance.wallpaperThumb,
  ),
  'wallpaper_url': const FirestoreStringConverter().toJson(
    instance.wallpaperUrl,
  ),
  'collections': const FirestoreStringListConverter().toJson(
    instance.collections,
  ),
  'createdAt': const FirestoreDateTimeConverter().toJson(instance.createdAt),
  'review': instance.review,
};

_FavouriteWallDocDto _$FavouriteWallDocDtoFromJson(Map<String, dynamic> json) =>
    _FavouriteWallDocDto(
      id: json['id'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['id']),
      provider: json['provider'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['provider']),
      url: json['url'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['url']),
      thumb: json['thumb'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['thumb']),
      category: json['category'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['category']),
      views: json['views'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['views']),
      resolution: json['resolution'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['resolution']),
      fav: json['fav'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['fav']),
      size: json['size'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['size']),
      photographer: json['photographer'] == null
          ? ''
          : const FirestoreStringConverter().fromJson(json['photographer']),
      collections: json['collections'] == null
          ? const <String>[]
          : const FirestoreStringListConverter().fromJson(json['collections']),
      createdAt: const FirestoreDateTimeConverter().fromJson(json['createdAt']),
    );

Map<String, dynamic> _$FavouriteWallDocDtoToJson(
  _FavouriteWallDocDto instance,
) => <String, dynamic>{
  'id': const FirestoreStringConverter().toJson(instance.id),
  'provider': const FirestoreStringConverter().toJson(instance.provider),
  'url': const FirestoreStringConverter().toJson(instance.url),
  'thumb': const FirestoreStringConverter().toJson(instance.thumb),
  'category': const FirestoreStringConverter().toJson(instance.category),
  'views': const FirestoreStringConverter().toJson(instance.views),
  'resolution': const FirestoreStringConverter().toJson(instance.resolution),
  'fav': const FirestoreStringConverter().toJson(instance.fav),
  'size': const FirestoreStringConverter().toJson(instance.size),
  'photographer': const FirestoreStringConverter().toJson(
    instance.photographer,
  ),
  'collections': const FirestoreStringListConverter().toJson(
    instance.collections,
  ),
  'createdAt': const FirestoreDateTimeConverter().toJson(instance.createdAt),
};
