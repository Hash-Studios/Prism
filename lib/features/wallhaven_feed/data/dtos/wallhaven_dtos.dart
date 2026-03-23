import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallhaven_dtos.freezed.dart';
part 'wallhaven_dtos.g.dart';

@freezed
abstract class WallhavenSearchResponseDto with _$WallhavenSearchResponseDto {
  const factory WallhavenSearchResponseDto({
    @Default(<WallhavenWallpaperDto>[]) List<WallhavenWallpaperDto> data,
    WallhavenMetaDto? meta,
  }) = _WallhavenSearchResponseDto;

  factory WallhavenSearchResponseDto.fromJson(Map<String, dynamic> json) => _$WallhavenSearchResponseDtoFromJson(json);
}

@freezed
abstract class WallhavenSingleResponseDto with _$WallhavenSingleResponseDto {
  const factory WallhavenSingleResponseDto({WallhavenWallpaperDto? data}) = _WallhavenSingleResponseDto;

  factory WallhavenSingleResponseDto.fromJson(Map<String, dynamic> json) => _$WallhavenSingleResponseDtoFromJson(json);
}

@freezed
abstract class WallhavenMetaDto with _$WallhavenMetaDto {
  const factory WallhavenMetaDto({
    @JsonKey(name: 'current_page') @Default(1) int currentPage,
    @JsonKey(name: 'last_page') @Default(1) int lastPage,
  }) = _WallhavenMetaDto;

  factory WallhavenMetaDto.fromJson(Map<String, dynamic> json) => _$WallhavenMetaDtoFromJson(json);
}

@freezed
abstract class WallhavenUploaderDto with _$WallhavenUploaderDto {
  const factory WallhavenUploaderDto({String? username}) = _WallhavenUploaderDto;

  factory WallhavenUploaderDto.fromJson(Map<String, dynamic> json) => _$WallhavenUploaderDtoFromJson(json);
}

@freezed
abstract class WallhavenWallpaperDto with _$WallhavenWallpaperDto {
  const factory WallhavenWallpaperDto({
    required String id,
    @Default('') String path,
    @Default('') String resolution,
    @JsonKey(name: 'file_size') int? fileSize,
    @Default('') String category,
    int? views,
    @JsonKey(name: 'favorites') int? favorites,
    @JsonKey(name: 'dimension_x') int? dimensionX,
    @JsonKey(name: 'dimension_y') int? dimensionY,
    @Default(<String>[]) List<String> colors,
    WallhavenThumbsDto? thumbs,
    @Default(<WallhavenTagDto>[]) List<WallhavenTagDto> tags,
    WallhavenUploaderDto? uploader,
  }) = _WallhavenWallpaperDto;

  factory WallhavenWallpaperDto.fromJson(Map<String, dynamic> json) => _$WallhavenWallpaperDtoFromJson(json);
}

@freezed
abstract class WallhavenThumbsDto with _$WallhavenThumbsDto {
  const factory WallhavenThumbsDto({String? large, String? original, String? small}) = _WallhavenThumbsDto;

  factory WallhavenThumbsDto.fromJson(Map<String, dynamic> json) => _$WallhavenThumbsDtoFromJson(json);
}

@freezed
abstract class WallhavenTagDto with _$WallhavenTagDto {
  const factory WallhavenTagDto({@Default('') String name}) = _WallhavenTagDto;

  factory WallhavenTagDto.fromJson(Map<String, dynamic> json) => _$WallhavenTagDtoFromJson(json);
}
