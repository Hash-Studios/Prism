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
  desc: json['desc'] == null ? '' : const FirestoreStringConverter().fromJson(json['desc']),
  collections: json['collections'] == null
      ? const <String>[]
      : const FirestoreStringListConverter().fromJson(json['collections']),
  tags: json['tags'] == null ? const <String>[] : const FirestoreStringListConverter().fromJson(json['tags']),
  review: json['review'] as bool? ?? false,
  aiMetadata: json['aiMetadata'] == null
      ? const <String, Object?>{}
      : const FirestoreJsonMapConverter().fromJson(json['aiMetadata']),
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
  'desc': const FirestoreStringConverter().toJson(instance.desc),
  'collections': const FirestoreStringListConverter().toJson(instance.collections),
  'tags': const FirestoreStringListConverter().toJson(instance.tags),
  'review': instance.review,
  'aiMetadata': const FirestoreJsonMapConverter().toJson(instance.aiMetadata),
};
