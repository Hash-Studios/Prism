import 'package:json_annotation/json_annotation.dart';

part 'icon_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class SetupIcon {
  String name;
  String url;

  SetupIcon({
    required this.name,
    required this.url,
  });

  factory SetupIcon.fromJson(Map<String, dynamic> json) =>
      _$SetupIconFromJson(json);
  Map<String, dynamic> toJson() => _$SetupIconToJson(this);
}
