import 'package:freezed_annotation/freezed_annotation.dart';

part 'pexels_dtos.freezed.dart';
part 'pexels_dtos.g.dart';

@freezed
abstract class PexelsSearchResponseDto with _$PexelsSearchResponseDto {
  const factory PexelsSearchResponseDto({
    @Default(1) int page,
    @JsonKey(name: 'per_page') @Default(0) int perPage,
    @JsonKey(name: 'total_results') @Default(0) int totalResults,
    @Default(<PexelsPhotoDto>[]) List<PexelsPhotoDto> photos,
  }) = _PexelsSearchResponseDto;

  factory PexelsSearchResponseDto.fromJson(Map<String, dynamic> json) => _$PexelsSearchResponseDtoFromJson(json);
}

@freezed
abstract class PexelsPhotoDto with _$PexelsPhotoDto {
  const factory PexelsPhotoDto({
    required int id,
    int? width,
    int? height,
    @Default('') String url,
    String? photographer,
    @JsonKey(name: 'photographer_url') String? photographerUrl,
    PexelsSrcDto? src,
  }) = _PexelsPhotoDto;

  factory PexelsPhotoDto.fromJson(Map<String, dynamic> json) => _$PexelsPhotoDtoFromJson(json);
}

@freezed
abstract class PexelsSrcDto with _$PexelsSrcDto {
  const factory PexelsSrcDto({
    @Default('') String original,
    String? large2x,
    String? large,
    String? medium,
    String? small,
    String? portrait,
    String? landscape,
    String? tiny,
  }) = _PexelsSrcDto;

  factory PexelsSrcDto.fromJson(Map<String, dynamic> json) => _$PexelsSrcDtoFromJson(json);
}
