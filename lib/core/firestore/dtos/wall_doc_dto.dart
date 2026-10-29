import 'package:Prism/core/firestore/converters/firestore_json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wall_doc_dto.freezed.dart';
part 'wall_doc_dto.g.dart';

bool _firestoreBool(Object? value) => value == true;
String _firestoreAiModel(Object? value) => value is String ? value : '';

@freezed
abstract class WallDocDto with _$WallDocDto {
  const factory WallDocDto({
    @FirestoreStringConverter() @Default('') String id,
    @FirestoreStringConverter() @Default('') String by,
    @FirestoreStringConverter() @Default('') String desc,
    @FirestoreStringConverter() @Default('') String category,
    @FirestoreStringConverter() @Default('') String size,
    @FirestoreStringConverter() @Default('') String resolution,
    @FirestoreStringConverter() @Default('') String email,
    @JsonKey(name: 'creatorUid') @FirestoreStringConverter() @Default('') String creatorUid,
    @JsonKey(name: 'wallpaper_provider') @FirestoreStringConverter() @Default('') String wallpaperProvider,
    @JsonKey(name: 'wallpaper_thumb') @FirestoreStringConverter() @Default('') String wallpaperThumb,
    @JsonKey(name: 'wallpaper_url') @FirestoreStringConverter() @Default('') String wallpaperUrl,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> collections,
    @FirestoreDateTimeConverter() DateTime? createdAt,
    @Default(false) bool review,
    @JsonKey(fromJson: _firestoreBool) @Default(false) bool isAiGenerated,
    @JsonKey(fromJson: _firestoreAiModel) @Default('') String aiModel,
    @JsonKey(name: 'aiMetadata')
    @FirestoreJsonMapConverter()
    @Default(<String, Object?>{})
    Map<String, Object?> aiMetadata,
    @JsonKey(name: 'depth') @FirestoreJsonMapConverter() @Default(<String, Object?>{}) Map<String, Object?> depth,
    @JsonKey(name: 'spatial') @FirestoreJsonMapConverter() @Default(<String, Object?>{}) Map<String, Object?> spatial,
  }) = _WallDocDto;

  factory WallDocDto.fromJson(Map<String, dynamic> json) => _$WallDocDtoFromJson(json);
}

@freezed
abstract class FavouriteWallDocDto with _$FavouriteWallDocDto {
  const factory FavouriteWallDocDto({
    @FirestoreStringConverter() @Default('') String id,
    @FirestoreStringConverter() @Default('') String provider,
    @FirestoreStringConverter() @Default('') String url,
    @FirestoreStringConverter() @Default('') String thumb,
    @FirestoreStringConverter() @Default('') String category,
    @FirestoreStringConverter() @Default('') String views,
    @FirestoreStringConverter() @Default('') String resolution,
    @FirestoreStringConverter() @Default('') String fav,
    @FirestoreStringConverter() @Default('') String size,
    @FirestoreStringConverter() @Default('') String photographer,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> collections,
    @FirestoreDateTimeConverter() DateTime? createdAt,
    @FirestoreDateTimeConverter() DateTime? favouritedAt,
    @JsonKey(includeIfNull: false) @FirestoreDateTimeConverter() DateTime? pinnedAt,
    @JsonKey(name: 'depth') @FirestoreJsonMapConverter() @Default(<String, Object?>{}) Map<String, Object?> depth,
    @JsonKey(name: 'spatial') @FirestoreJsonMapConverter() @Default(<String, Object?>{}) Map<String, Object?> spatial,
  }) = _FavouriteWallDocDto;

  factory FavouriteWallDocDto.fromJson(Map<String, dynamic> json) => _$FavouriteWallDocDtoFromJson(json);
}
