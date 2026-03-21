import 'dart:convert';

import 'package:Prism/core/wallpaper/setup_wallpaper_value.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDocument {
  const FirestoreDocument(this.id, this.payload);

  final String id;
  final Map<String, dynamic> payload;

  String get by => _string('by');
  String get icon => _string('icon');
  String get iconUrl => _string('icon_url');
  DateTime? get createdAt => _dateTime('created_at') ?? _dateTime('createdAt');
  String get desc => _string('desc');
  String get email => _string('email');
  String get image => _string('image');
  String get name => _string('name');
  String get userPhoto => _string('userPhoto');
  String get wallId => _string('wall_id');
  String get wallpaperProvider => _string('wallpaper_provider');
  String get wallpaperThumb => _string('wallpaper_thumb');
  String get wallpaperUrl => _string('wallpaper_url');
  SetupWallpaperValue get setupWallpaperValue {
    final value = payload['wallpaper_url'];
    if (value is List) {
      final String encoded = jsonEncode(value.map((entry) => entry?.toString() ?? '').toList(growable: false));
      return SetupWallpaperValue.parse(encoded);
    }
    return SetupWallpaperValue.parse(value?.toString());
  }

  String get widget => _string('widget');
  String get widget2 => _string('widget2');
  String get widgetUrl => _string('widget_url');
  String get widgetUrl2 => _string('widget_url2');
  String get link => _string('link');
  bool get review => _bool('review');
  String get resolution => _string('resolution');
  String get size => _string('size');
  List<String> get collections => _stringList('collections');

  Map<String, dynamic> data() => payload;
  dynamic operator [](String key) => payload[key];

  String _string(String key) => payload[key]?.toString() ?? '';

  bool _bool(String key) {
    final value = payload[key];
    if (value is bool) {
      return value;
    }
    return value?.toString().toLowerCase() == 'true';
  }

  DateTime? _dateTime(String key) {
    final value = payload[key];
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  List<String> _stringList(String key) {
    final value = payload[key];
    if (value is List) {
      return value.map((entry) => entry?.toString() ?? '').where((entry) => entry.isNotEmpty).toList(growable: false);
    }
    return const <String>[];
  }
}
