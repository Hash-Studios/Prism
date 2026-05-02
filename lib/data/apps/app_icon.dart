import 'package:Prism/core/wallpaper/parse_helpers.dart';

final class AppIcon {
  const AppIcon({required this.id, required this.name, required this.iconUrl, required this.link});

  final String id;
  final String name;
  final String iconUrl;
  final String link;

  factory AppIcon.fromMap(Map<Object?, Object?> json) {
    return AppIcon(
      id: parseString(json['id']),
      name: parseString(json['name']),
      iconUrl: parseString(json['icon']),
      link: parseString(json['link']),
    );
  }

  Map<String, String> toMap() {
    return <String, String>{'id': id, 'name': name, 'icon': iconUrl, 'link': link};
  }
}
