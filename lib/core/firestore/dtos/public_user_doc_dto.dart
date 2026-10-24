import 'package:Prism/core/firestore/converters/firestore_json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_user_doc_dto.freezed.dart';
part 'public_user_doc_dto.g.dart';

@freezed
abstract class PublicUserDocDto with _$PublicUserDocDto {
  const factory PublicUserDocDto({
    @FirestoreStringConverter() @Default('') String name,
    @FirestoreStringConverter() @Default('') String username,
    @FirestoreStringConverter() @Default('') String profilePhoto,
    @FirestoreStringConverter() @Default('') String bio,
    @FirestoreStringMapConverter() @Default(<String, String>{}) Map<String, String> links,
    @FirestoreStringConverter() @Default('') String coverPhoto,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> badges,
    @Default(0) int xp,
    @FirestoreStringMapConverter() @Default(<String, String>{}) Map<String, String> cosmetics,
    @Default(0) int followerCount,
    @Default(0) int followingCount,
  }) = _PublicUserDocDto;

  factory PublicUserDocDto.fromJson(Map<String, dynamic> json) => _$PublicUserDocDtoFromJson(json);
}
