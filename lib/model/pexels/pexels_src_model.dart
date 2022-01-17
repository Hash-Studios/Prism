import 'package:json_annotation/json_annotation.dart';

part 'pexels_src_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class PexelsSrc {
  String original;
  String large2x;
  String large;
  String medium;
  String small;
  String portrait;
  String landscape;
  String tiny;

  PexelsSrc({
    required this.original,
    required this.large2x,
    required this.large,
    required this.medium,
    required this.small,
    required this.portrait,
    required this.landscape,
    required this.tiny,
  });

  factory PexelsSrc.fromJson(Map<String, dynamic> json) =>
      _$PexelsSrcFromJson(json);

  Map<String, dynamic> toJson() => _$PexelsSrcToJson(this);
}
