import 'package:Prism/core/firestore/converters/firestore_json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_user_doc_dto.freezed.dart';
part 'public_user_doc_dto.g.dart';

@freezed
abstract class PublicUserDocDto with _$PublicUserDocDto {
  const factory PublicUserDocDto({
    @FirestoreStringConverter() @Default('') String id,
    @FirestoreStringConverter() @Default('') String name,
    @FirestoreStringConverter() @Default('') String email,
    @FirestoreStringConverter() @Default('') String username,
    @FirestoreStringConverter() @Default('') String profilePhoto,
    @FirestoreStringConverter() @Default('') String bio,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> followers,
    @FirestoreStringListConverter() @Default(<String>[]) List<String> following,
    @FirestoreStringMapConverter() @Default(<String, String>{}) Map<String, String> links,
    @Default(false) bool premium,
    @FirestoreStringConverter() @Default('') String coverPhoto,
  }) = _PublicUserDocDto;

  factory PublicUserDocDto.fromJson(Map<String, dynamic> json) => _$PublicUserDocDtoFromJson(json);
}
