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
    @JsonKey(name: 'creatorUid') @FirestoreStringConverter() @Default('') String creatorUid,
    @JsonKey(name: 'userPhoto') @FirestoreStringConverter() @Default('') String userPhoto,
    String? title,
    @FirestoreStringConverter() @Default('') String desc,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> collections,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> tags,
    @FirestoreStringConverter() @Default('') String category,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> colors,
    @Default(false) bool review,
    @JsonKey(name: 'aiMetadata')
    @FirestoreJsonMapConverter()
    @Default(<String, Object?>{})
    Map<String, Object?> aiMetadata,
    @JsonKey(name: 'is_streak_exclusive') @Default(false) bool isStreakExclusive,
    @JsonKey(name: 'required_streak_days') int? requiredStreakDays,
    @JsonKey(name: 'streak_shop_coin_cost') int? streakShopCoinCost,
    @FirestoreDateTimeConverter() DateTime? boostedUntil,
    @JsonKey(name: 'depth') @FirestoreJsonMapConverter() @Default(<String, Object?>{}) Map<String, Object?> depth,
    @JsonKey(name: 'spatial') @FirestoreJsonMapConverter() @Default(<String, Object?>{}) Map<String, Object?> spatial,
    @Default(false) bool isAiGenerated,
    @FirestoreStringConverter() @Default('') String aiPrompt,
    @FirestoreStringConverter() @Default('') String aiStylePreset,
    @FirestoreStringConverter() @Default('') String aiModel,
    @FirestoreStringConverter() @Default('') String origin,
    @FirestoreStringConverter() @Default('') String remixOf,
    int? remixCount,
  }) = _PrismWallDocDto;

  factory PrismWallDocDto.fromJson(Map<String, dynamic> json) => _$PrismWallDocDtoFromJson(json);
}
