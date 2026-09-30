// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pexels_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PexelsSearchResponseDto _$PexelsSearchResponseDtoFromJson(
  Map<String, dynamic> json,
) => _PexelsSearchResponseDto(
  page: (json['page'] as num?)?.toInt() ?? 1,
  perPage: (json['per_page'] as num?)?.toInt() ?? 0,
  totalResults: (json['total_results'] as num?)?.toInt() ?? 0,
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => PexelsPhotoDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PexelsPhotoDto>[],
);

Map<String, dynamic> _$PexelsSearchResponseDtoToJson(
  _PexelsSearchResponseDto instance,
) => <String, dynamic>{
  'page': instance.page,
  'per_page': instance.perPage,
  'total_results': instance.totalResults,
  'photos': instance.photos,
};

_PexelsPhotoDto _$PexelsPhotoDtoFromJson(Map<String, dynamic> json) =>
    _PexelsPhotoDto(
      id: (json['id'] as num).toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      url: json['url'] as String? ?? '',
      photographer: json['photographer'] as String?,
      photographerUrl: json['photographer_url'] as String?,
      src: json['src'] == null
          ? null
          : PexelsSrcDto.fromJson(json['src'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PexelsPhotoDtoToJson(_PexelsPhotoDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'width': instance.width,
      'height': instance.height,
      'url': instance.url,
      'photographer': instance.photographer,
      'photographer_url': instance.photographerUrl,
      'src': instance.src,
    };

_PexelsSrcDto _$PexelsSrcDtoFromJson(Map<String, dynamic> json) =>
    _PexelsSrcDto(
      original: json['original'] as String? ?? '',
      large2x: json['large2x'] as String?,
      large: json['large'] as String?,
      medium: json['medium'] as String?,
      small: json['small'] as String?,
      portrait: json['portrait'] as String?,
      landscape: json['landscape'] as String?,
      tiny: json['tiny'] as String?,
    );

Map<String, dynamic> _$PexelsSrcDtoToJson(_PexelsSrcDto instance) =>
    <String, dynamic>{
      'original': instance.original,
      'large2x': instance.large2x,
      'large': instance.large,
      'medium': instance.medium,
      'small': instance.small,
      'portrait': instance.portrait,
      'landscape': instance.landscape,
      'tiny': instance.tiny,
    };
