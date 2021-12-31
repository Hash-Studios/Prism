import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:prism/model/setup/icon_model.dart';
import 'package:prism/model/setup/wallpaper_model.dart';
import 'package:prism/model/setup/widget_model.dart';

part 'setup_model.g.dart';

class TimestampConverter implements JsonConverter<DateTime, Timestamp> {
  const TimestampConverter();

  @override
  DateTime fromJson(Timestamp timestamp) {
    return timestamp.toDate();
  }

  @override
  Timestamp toJson(DateTime date) => Timestamp.fromDate(date);
}

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class Setup {
  String id;
  String by;
  @TimestampConverter()
  DateTime createdAt;
  String name;
  String? desc;
  String email;
  String userPhoto;
  String image;
  List<SetupIcon> icons;
  List<SetupWidget> widgets;
  List<SetupWallpaper> wallpapers;

  Setup({
    required this.id,
    required this.by,
    required this.email,
    this.desc,
    required this.icons,
    required this.createdAt,
    required this.image,
    required this.name,
    required this.userPhoto,
    required this.wallpapers,
    required this.widgets,
  });

  factory Setup.fromJson(Map<String, dynamic> json) => _$SetupFromJson(json);
  Map<String, dynamic> toJson() => _$SetupToJson(this);
}
