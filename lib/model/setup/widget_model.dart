import 'package:json_annotation/json_annotation.dart';

part 'widget_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class SetupWidget {
  String name;
  String url;

  SetupWidget({
    required this.name,
    required this.url,
  });

  factory SetupWidget.fromJson(Map<String, dynamic> json) =>
      _$SetupWidgetFromJson(json);
  Map<String, dynamic> toJson() => _$SetupWidgetToJson(this);
}
