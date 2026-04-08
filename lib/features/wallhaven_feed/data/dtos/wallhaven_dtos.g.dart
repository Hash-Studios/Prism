// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallhaven_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WallhavenSearchResponseDto _$WallhavenSearchResponseDtoFromJson(
  Map<String, dynamic> json,
) => _WallhavenSearchResponseDto(
  data:
      (json['data'] as List<dynamic>?)
          ?.map(
            (e) => WallhavenWallpaperDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <WallhavenWallpaperDto>[],
  meta: json['meta'] == null
      ? null
      : WallhavenMetaDto.fromJson(json['meta'] as Map<String, dynamic>),
);

Map<String, dynamic> _$WallhavenSearchResponseDtoToJson(
  _WallhavenSearchResponseDto instance,
) => <String, dynamic>{'data': instance.data, 'meta': instance.meta};

_WallhavenSingleResponseDto _$WallhavenSingleResponseDtoFromJson(
  Map<String, dynamic> json,
) => _WallhavenSingleResponseDto(
  data: json['data'] == null
      ? null
      : WallhavenWallpaperDto.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$WallhavenSingleResponseDtoToJson(
  _WallhavenSingleResponseDto instance,
) => <String, dynamic>{'data': instance.data};

_WallhavenMetaDto _$WallhavenMetaDtoFromJson(Map<String, dynamic> json) =>
    _WallhavenMetaDto(
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$WallhavenMetaDtoToJson(_WallhavenMetaDto instance) =>
    <String, dynamic>{
      'current_page': instance.currentPage,
      'last_page': instance.lastPage,
    };

_WallhavenUploaderDto _$WallhavenUploaderDtoFromJson(
  Map<String, dynamic> json,
) => _WallhavenUploaderDto(username: json['username'] as String?);

Map<String, dynamic> _$WallhavenUploaderDtoToJson(
  _WallhavenUploaderDto instance,
) => <String, dynamic>{'username': instance.username};

_WallhavenWallpaperDto _$WallhavenWallpaperDtoFromJson(
  Map<String, dynamic> json,
) => _WallhavenWallpaperDto(
  id: json['id'] as String,
  path: json['path'] as String? ?? '',
  resolution: json['resolution'] as String? ?? '',
  fileSize: (json['file_size'] as num?)?.toInt(),
  category: json['category'] as String? ?? '',
  views: (json['views'] as num?)?.toInt(),
  favorites: (json['favorites'] as num?)?.toInt(),
  dimensionX: (json['dimension_x'] as num?)?.toInt(),
  dimensionY: (json['dimension_y'] as num?)?.toInt(),
  colors:
      (json['colors'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  thumbs: json['thumbs'] == null
      ? null
      : WallhavenThumbsDto.fromJson(json['thumbs'] as Map<String, dynamic>),
  tags:
      (json['tags'] as List<dynamic>?)
          ?.map((e) => WallhavenTagDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <WallhavenTagDto>[],
  uploader: json['uploader'] == null
      ? null
      : WallhavenUploaderDto.fromJson(json['uploader'] as Map<String, dynamic>),
);

Map<String, dynamic> _$WallhavenWallpaperDtoToJson(
  _WallhavenWallpaperDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'path': instance.path,
  'resolution': instance.resolution,
  'file_size': instance.fileSize,
  'category': instance.category,
  'views': instance.views,
  'favorites': instance.favorites,
  'dimension_x': instance.dimensionX,
  'dimension_y': instance.dimensionY,
  'colors': instance.colors,
  'thumbs': instance.thumbs,
  'tags': instance.tags,
  'uploader': instance.uploader,
};

_WallhavenThumbsDto _$WallhavenThumbsDtoFromJson(Map<String, dynamic> json) =>
    _WallhavenThumbsDto(
      large: json['large'] as String?,
      original: json['original'] as String?,
      small: json['small'] as String?,
    );

Map<String, dynamic> _$WallhavenThumbsDtoToJson(_WallhavenThumbsDto instance) =>
    <String, dynamic>{
      'large': instance.large,
      'original': instance.original,
      'small': instance.small,
    };

_WallhavenTagDto _$WallhavenTagDtoFromJson(Map<String, dynamic> json) =>
    _WallhavenTagDto(name: json['name'] as String? ?? '');

Map<String, dynamic> _$WallhavenTagDtoToJson(_WallhavenTagDto instance) =>
    <String, dynamic>{'name': instance.name};
