import 'package:Prism/core/firestore/converters/firestore_json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'prism_wall_doc_dto.freezed.dart';
part 'prism_wall_doc_dto.g.dart';

@freezed
abstract class PrismWallDocDto with _$PrismWallDocDto {
  const factory PrismWallDocDto({
    @FirestoreStringConverter() @Default('') String id,
    @JsonKey(name: 'wallpaper_url') @FirestoreStringConverter() @Default('') String wallpaperUrl,
    @JsonKey(name: 'wallpaper_thumb') @FirestoreStringConverter() @Default('') String wallpaperThumb,
    @JsonKey(name: 'wallpaper_provider') @FirestoreStringConverter() @Default('') String wallpaperProvider,
    @FirestoreStringConverter() @Default('') String resolution,
    @JsonKey(name: 'file_size') int? fileSize,
    @FirestoreDateTimeConverter() DateTime? createdAt,
    @JsonKey(name: 'uploadedBy') @FirestoreStringConverter() @Default('') String uploadedBy,
    @FirestoreStringConverter() @Default('') String by,
    @FirestoreStringConverter() @Default('') String email,
    @JsonKey(name: 'userPhoto') @FirestoreStringConverter() @Default('') String userPhoto,
    @FirestoreStringConverter() @Default('') String desc,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> collections,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> tags,
    @Default(false) bool review,
    @JsonKey(name: 'aiMetadata')
    @FirestoreJsonMapConverter()
    @Default(<String, Object?>{})
    Map<String, Object?> aiMetadata,
    @JsonKey(name: 'is_streak_exclusive') @Default(false) bool isStreakExclusive,
    @JsonKey(name: 'required_streak_days') int? requiredStreakDays,
    @JsonKey(name: 'streak_shop_coin_cost') int? streakShopCoinCost,
  }) = _PrismWallDocDto;

  factory PrismWallDocDto.fromJson(Map<String, dynamic> json) => _$PrismWallDocDtoFromJson(json);
}
