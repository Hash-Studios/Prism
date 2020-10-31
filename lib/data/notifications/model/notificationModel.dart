import 'package:hive/hive.dart';
part 'notificationModel.g.dart';

@HiveType(typeId: 0)
class NotifData {
  @HiveField(0)
  final String title;
  @HiveField(1)
  final String pageName;
  @HiveField(2)
  final String desc;
  @HiveField(3)
  final String imageUrl;
  @HiveField(4)
  final List arguments;
  @HiveField(5)
  final String url;
  @HiveField(6)
  final DateTime createdAt;

  NotifData(
      {this.pageName,
      this.title,
      this.desc,
      this.imageUrl,
      this.arguments,
      this.url,
      this.createdAt});
}
