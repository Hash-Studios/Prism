import 'package:hive_io/hive_io.dart';
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
  @HiveField(7)
  final bool? read;
  @HiveField(8)
  final String? route;
  @HiveField(9)
  final String? wallId;

  InAppNotif({
    required this.pageName,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.arguments,
    required this.url,
    required this.createdAt,
    required this.read,
    this.route,
    this.wallId,
  });

  static String? _optionalImageUrl(dynamic value) {
    final s = value?.toString().trim() ?? '';
    if (s.isEmpty) return null;
    try {
      final uri = Uri.parse(s);
      if (uri.host.isEmpty) return null;
      return s;
    } catch (_) {
      return null;
    }
  }

  static DateTime _parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      if (value is Map && value.containsKey('_seconds')) {
        final sec = value['_seconds'] as int? ?? 0;
        final nanosec = value['_nanoseconds'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(sec * 1000 + nanosec ~/ 1000000);
      }
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  factory InAppNotif.fromSnapshot(Map<String, dynamic> data) {
    final dataMap = data['data'] is Map ? data['data'] as Map<String, dynamic> : <String, dynamic>{};
    return InAppNotif(
      pageName: dataMap['pageName']?.toString() ?? '',
      title: data['notification']?['title']?.toString() ?? '',
      body: data['notification']?['body']?.toString() ?? '',
      imageUrl: _optionalImageUrl(dataMap['imageUrl']),
      arguments: dataMap['arguments'] is List ? dataMap['arguments'] as List : [],
      url: dataMap['url']?.toString() ?? '',
      createdAt: _parseCreatedAt(data['createdAt']),
      read: false,
      route: dataMap['route']?.toString(),
      wallId: dataMap['wall_id']?.toString(),
    );
  }
}
