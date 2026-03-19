import 'package:Prism/core/firestore/converters/firestore_json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'setup_doc_dto.freezed.dart';
part 'setup_doc_dto.g.dart';

@freezed
abstract class SetupDocDto with _$SetupDocDto {
  const factory SetupDocDto({
    @FirestoreStringConverter() @Default('') String id,
    @FirestoreStringConverter() @Default('') String by,
    @FirestoreStringConverter() @Default('') String icon,
    @JsonKey(name: 'icon_url') @FirestoreStringConverter() @Default('') String iconUrl,
    @JsonKey(name: 'created_at') @FirestoreDateTimeConverter() DateTime? createdAt,
    @FirestoreStringConverter() @Default('') String desc,
    @FirestoreStringConverter() @Default('') String email,
    @FirestoreStringConverter() @Default('') String image,
    @FirestoreStringConverter() @Default('') String name,
    @FirestoreStringConverter() @Default('') String userPhoto,
    @JsonKey(name: 'wall_id') @FirestoreStringConverter() @Default('') String wallId,
    @JsonKey(name: 'wallpaper_provider') @FirestoreStringConverter() @Default('') String wallpaperProvider,
    @JsonKey(name: 'wallpaper_thumb') @FirestoreStringConverter() @Default('') String wallpaperThumb,
    @JsonKey(name: 'wallpaper_url') @FirestoreStringConverter() @Default('') String wallpaperUrl,
    @FirestoreStringConverter() @Default('') String widget,
    @FirestoreStringConverter() @Default('') String widget2,
    @JsonKey(name: 'widget_url') @FirestoreStringConverter() @Default('') String widgetUrl,
    @JsonKey(name: 'widget_url2') @FirestoreStringConverter() @Default('') String widgetUrl2,
    @FirestoreStringConverter() @Default('') String link,
    @Default(false) bool review,
    @FirestoreStringConverter() @Default('') String resolution,
    @FirestoreStringConverter() @Default('') String size,
  }) = _SetupDocDto;

  factory SetupDocDto.fromJson(Map<String, dynamic> json) => _$SetupDocDtoFromJson(json);
}
