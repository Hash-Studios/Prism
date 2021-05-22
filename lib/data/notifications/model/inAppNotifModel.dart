import 'package:hive/hive.dart';
part 'inAppNotifModel.g.dart';

@HiveType(typeId: 9)
class InAppNotif {
  @HiveField(0)
  final String? title;
  @HiveField(1)
  final String? pageName;
  @HiveField(2)
  final String? body;
  @HiveField(3)
  final String? imageUrl;
  @HiveField(4)
  final List? arguments;
  @HiveField(5)
  final String? url;
  @HiveField(6)
  final DateTime? createdAt;

  InAppNotif({
    required this.pageName,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.arguments,
    required this.url,
    required this.createdAt,
  });

  factory InAppNotif.fromSnapshot(Map<String, dynamic> data) => InAppNotif(
      pageName: data['data']['pageName'].toString(),
      title: data['notification']['title'].toString(),
      body: data['notification']['body'].toString(),
      imageUrl: (data['data']['imageUrl'] ??
              "https://w.wallhaven.cc/full/q6/wallhaven-q6mg5d.jpg")
          .toString(),
      arguments: data['data']['arguments'] as List,
      url: data['data']['url'].toString(),
      createdAt: data['createdAt'].toDate() as DateTime);
}
