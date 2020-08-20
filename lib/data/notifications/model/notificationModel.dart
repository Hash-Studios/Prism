import 'package:Prism/routes/routing_constants.dart';
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

  NotifData(
      {this.pageName, this.title, this.desc, this.imageUrl, this.arguments});
}

var sampleNotificationData = [
  NotifData(
    title: "Notification 1",
    desc: "This is a sample notification.",
    imageUrl:
        "https://image.freepik.com/free-vector/abstract-gradient-background-with-fluid-shapes_47641-19.jpg",
    pageName: DownloadRoute,
    arguments: [],
  ),
  NotifData(
    title: "Notification 2",
    desc: "This is a sample notification.",
    imageUrl:
        "https://image.freepik.com/free-vector/abstract-gradient-background-with-fluid-shapes_47641-19.jpg",
    pageName: DownloadRoute,
    arguments: [],
  ),
  NotifData(
    title: "Notification 1",
    desc: "This is a sample notification.",
    imageUrl:
        "https://image.freepik.com/free-vector/abstract-gradient-background-with-fluid-shapes_47641-19.jpg",
    pageName: DownloadRoute,
    arguments: [],
  ),
  NotifData(
    title: "Notification 3",
    desc: "This is a sample notification.",
    imageUrl:
        "https://image.freepik.com/free-vector/abstract-gradient-background-with-fluid-shapes_47641-19.jpg",
    pageName: DownloadRoute,
    arguments: [],
  ),
  NotifData(
    title: "Notification 1",
    desc: "This is a sample notification.",
    imageUrl:
        "https://image.freepik.com/free-vector/abstract-gradient-background-with-fluid-shapes_47641-19.jpg",
    pageName: DownloadRoute,
    arguments: [],
  ),
];
