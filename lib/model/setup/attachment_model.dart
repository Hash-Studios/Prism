import 'package:json_annotation/json_annotation.dart';

part 'attachment_model.g.dart';

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class SetupAttachment {
  String name;
  String url;

  SetupAttachment({
    required this.name,
    required this.url,
  });

  factory SetupAttachment.fromJson(Map<String, dynamic> json) =>
      _$SetupAttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$SetupAttachmentToJson(this);
}
